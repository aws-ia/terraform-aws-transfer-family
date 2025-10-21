# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.

import importlib
import ipaddress
import json
import logging
import os
import re
from aws_lambda_powertools import Tracer

tracer = Tracer()

import boto3
import botocore
from boto3.dynamodb.conditions import Key
from idp_modules import util


logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


os.environ["AWS_STS_REGIONAL_ENDPOINTS"] = "regional"

AWS_REGION = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", ""))

USERS_TABLE_ID = os.environ["USERS_TABLE"]
IDENTITY_PROVIDERS_TABLE_ID = os.environ["IDENTITY_PROVIDERS_TABLE"]
USER_NAME_DELIMITER = os.environ["USER_NAME_DELIMITER"]

ACCOUNT_ID = boto3.client('sts', config=util.boto3_config).get_caller_identity().get('Account')
USERS_TABLE = boto3.resource("dynamodb", config=util.boto3_config).Table(USERS_TABLE_ID)
IDENTITY_PROVIDERS_TABLE = boto3.resource("dynamodb",config=util.boto3_config).Table(IDENTITY_PROVIDERS_TABLE_ID)


class IdpHandlerException(Exception):
    """Used to raise handler exceptions"""

    pass


@tracer.capture_method
def ip_in_cidr_list(ip_address, cidr_list):
    for cidr in cidr_list:
        logger.debug("Checking Allowed IP CIDR: {}".format(cidr))
        network = ipaddress.ip_network(cidr)
        if ipaddress.ip_address(ip_address) in network:
            logger.info("Matched {} to IP CIDR {}".format(ip_address, cidr))
            return True
        else:
            logger.debug(
                "Source IP {} doesn't match IP CIDR {}".format(ip_address, cidr)
            )

    return False


@tracer.capture_lambda_handler
def lambda_handler(event, context):
    response_data = {}

    logger.info({i: event[i] for i in event if i not in ["password"]})

    if "username" not in event or "serverId" not in event:
        raise IdpHandlerException("Incoming username or serverId missing  - Unexpected")

    input_username = event["username"].lower()
    logger.info(f"Username: {input_username}, ServerId: {event['serverId']}")
    tracer.put_annotation(key="transfer_user", value=input_username)


    # Parse the username to get user and identity provider (if specified)
    parsed_username = input_username.split(USER_NAME_DELIMITER)

    if 1 < len(parsed_username):
        if (
            USER_NAME_DELIMITER == "@" or USER_NAME_DELIMITER == "@@"
        ):  # support format <user>@<idp>   OR <user>@@<idp>
            username = USER_NAME_DELIMITER.join(parsed_username[:-1])
            identity_provider = parsed_username[-1]
        else:  # anything else is in this order <idp>\<user> , <idp>/<user>
            username = USER_NAME_DELIMITER.join(parsed_username[1:])
            identity_provider = parsed_username[0]
    else:
        username = parsed_username[0]
        identity_provider = None

    logger.info(
        f"Parsed username and IdP: Username: {username} IDP: {identity_provider}"
    )
    if username == "$" or username == "$default$":
        raise IdpHandlerException(f"Username $default$ is reserved and cannot be used.")
    
    # Lookup user
    if identity_provider:
        user_record = USERS_TABLE.get_item(
            Key={"user": username, "identity_provider_key": identity_provider}
        ).get("Item", None)
    else:
        user_record = USERS_TABLE.query(
            KeyConditionExpression=Key("user").eq(username)
        ).get("Items", None)
        logger.debug(f"user_record query result: {user_record}")
        if 0 < len(user_record):
            user_record = user_record[0]
        else:
            user_record = None

    if not user_record:
        logger.info(
            f"Record for user {username} identity provider {identity_provider} not found, retrieving default user record"
        )
        user_record = USERS_TABLE.query(
            KeyConditionExpression=Key("user").eq("$default$")
        ).get("Items", None)
        logger.debug(f"user_record query result: {user_record}")
        if 0 < len(user_record):
            user_record = user_record[0]
        else:
            raise IdpHandlerException(f"no matching user records found")

    logger.info(f"user_record: {user_record}")

    source_ip = event["sourceIp"]

    # Check IP allow list for user
    user_ipv4_allow_list = user_record.get("ipv4_allow_list", "")
    logger.debug(f"IPv4 Allow List: {user_ipv4_allow_list}")
    if not user_ipv4_allow_list or user_ipv4_allow_list == "":
        logger.info("No user IPv4 allow list is present, skipping check.")
    else:
        if not ip_in_cidr_list(source_ip, user_ipv4_allow_list):
            raise IdpHandlerException(
                f"Source IP {source_ip} is not allowed to connect."
            )

    # Lookup identity provider config
    identity_provider = user_record.get("identity_provider_key", "$default$")
    logger.info(f"Fetching identity provider record for {identity_provider}")
    identity_provider_record = IDENTITY_PROVIDERS_TABLE.get_item(
        Key={"provider": identity_provider}
    ).get("Item", None)
    logger.debug(f"identity_provider_record: {identity_provider_record}")
    tracer.put_annotation(key="identity_provider", value=identity_provider_record["provider"])
    if identity_provider_record is None:
        raise IdpHandlerException(
            f"Identity provider {identity_provider} is not defined in the table {IDENTITY_PROVIDERS_TABLE}."
        )
    
    if identity_provider_record.get('disabled', False):
        raise IdpHandlerException(
                f"Identity provider {identity_provider} is disabled."
            )

    # Check IP allow list for IdP
    identity_provider_ipv4_allow_list = identity_provider_record.get(
        "ipv4_allow_list", ""
    )
    logger.debug(f"IPv4 Allow List: {identity_provider_ipv4_allow_list}")
    if not identity_provider_ipv4_allow_list or identity_provider_ipv4_allow_list == "":
        logger.info("No identity provider IPv4 allow list is present, skipping check.")
    else:
        if not ip_in_cidr_list(source_ip, identity_provider_ipv4_allow_list):
            raise IdpHandlerException(
                f"Source IP {source_ip} is not allowed to connect."
            )

    # Merge AWS transfer session values from identity provider and user records to begin building response. Values in user record always supersede the identity provider record, though identity provider modules have final say in further manipulating these values, this eliminates a lot of duplicate logic that would otherwise be written in provider modules.
    user_record.setdefault("config", {})
    identity_provider_record.setdefault("config", {})

    if "Role" in user_record["config"]:
        response_data["Role"] = user_record["config"]["Role"]
        logger.info(
            f"Using Role value {user_record['config']['Role']} from user record for user {input_username}"
        )
    elif "Role" in identity_provider_record["config"]:
        logger.info(
            f"Using role value {identity_provider_record['config']['Role']} from identity provider record {identity_provider} for user {input_username}"
        )
        response_data["Role"] = identity_provider_record["config"]["Role"]
    else:
        logger.warning(
            f"Role arn not found in user record for {input_username} or identity provider record {identity_provider}. It may still be provided by identity provider response."
        )

    # These are optional
    if "Policy" in user_record["config"]:
        logger.info(f"Using Policy value from user record for user {input_username}")
        response_data["Policy"] = user_record["config"]["Policy"]
    elif "Role" in identity_provider_record["config"]:
        logger.info(
            f"Using Policy value from identity provider record {identity_provider} for user {input_username}"
        )
        response_data["Role"] = identity_provider_record["config"]["Policy"]
    else:
        logger.info(
            f"No Policy value found in  user record for {input_username} or identity provider record {identity_provider}, skipping"
        )

    if "HomeDirectoryDetails" in user_record["config"]:
        logger.info(f"HomeDirectoryDetails found in record for user {input_username}")
        response_data["HomeDirectoryDetails"] = user_record["config"][
            "HomeDirectoryDetails"
        ]
        response_data["HomeDirectoryType"] = "LOGICAL"
    elif "HomeDirectory" in user_record["config"]:
        logger.info(
            f"HomeDirectory found for user {input_username} - Cannot be used with HomeDirectoryDetails"
        )
        response_data["HomeDirectory"] = user_record["config"]["HomeDirectory"]
        response_data["HomeDirectoryType"] = "PATH"
    elif "HomeDirectoryDetails" in identity_provider_record["config"]:
        logger.info(
            f"HomeDirectoryDetails found in identity provider record {identity_provider} for user {input_username} - Applying setting for virtual folders"
        )
        response_data["HomeDirectoryDetails"] = identity_provider_record["config"][
            "HomeDirectoryDetails"
        ]
        response_data["HomeDirectoryType"] = "LOGICAL"
    elif "HomeDirectory" in identity_provider_record["config"]:
        logger.info(
            f"HomeDirectory found in identity provider record {identity_provider} for user {input_username} - Cannot be used with HomeDirectoryDetails"
        )
        response_data["HomeDirectory"] = identity_provider_record["config"][
            "HomeDirectory"
        ]
        response_data["HomeDirectoryType"] = "PATH"
    else:
        logger.warning(
            f"HomeDirectory and HomeDirectoryDetails in user record for {input_username} or identity provider record {identity_provider}"
        )

    if "PosixProfile" in user_record["config"]:
        logger.info(
            f"Using PosixProfile value from user record for user {input_username}"
        )
        response_data["PosixProfile"] = user_record["config"]["PosixProfile"]
    elif "PosixProfile" in identity_provider_record:
        logger.info(
            f"Using PosixProfile value from identity provider record {identity_provider} for user {input_username}"
        )
        response_data["PosixProfile"] = identity_provider_record["config"][
            "PosixProfile"
        ]
    else:
        logger.info(
            f"PosixProfile not found in user record for {input_username} or identity provider record {identity_provider}, won't be set."
        )

    # Intentionally, we DO NOT merge PublicKeys entries from identity provider record because it implies shared credentials. PublicKeys entries should only come from user records or in values returned by the identity provider if implemented.

    logger.debug(
        f"Response Data before processing with IdP module: {response_data}"
    )

    if event.get("password", "").strip() == "":
        logger.info(f"No password provided, performing public key auth.")   
        authn_method = util.AuthenticationMethod.PUBLIC_KEY
    else:
        logger.info(f"Password provided, performing password auth.")
        authn_method = util.AuthenticationMethod.PASSWORD

    # Some identity providers have built-in public key support, as specified in their config. If they don't, fall back to the public_key module.
    if (
        authn_method == util.AuthenticationMethod.PUBLIC_KEY
        and not identity_provider_record.get("public_key_support", False)
    ):
        from idp_modules import public_key

        response_data = public_key.handle_auth(
            event=event,
            parsed_username=parsed_username,
            user_record=user_record,
            identity_provider_record=identity_provider_record,
            response_data=response_data,
            authn_method=authn_method,
        )
    else:
        # Load the identity provider module and perform authentication with the provider
        identity_provider_module = importlib.import_module(
            f'idp_modules.{identity_provider_record["module"]}'
        )
        response_data = identity_provider_module.handle_auth(
            event=event,
            parsed_username=username,
            user_record=user_record,
            identity_provider_record=identity_provider_record,
            response_data=response_data,
            authn_method=authn_method,
        )

    # HomeDirectoryDetails must be a stringified list, check if any paths have a region filter and apply the filter.
    if "HomeDirectoryDetails" in response_data:
        if type(response_data["HomeDirectoryDetails"]) == list:
            filtered_home_directory_details = []
            for entry in response_data["HomeDirectoryDetails"]:
                if "regions" in entry:
                    if not AWS_REGION.lower() in entry["regions"]:
                        logger.debug(f"Virtual directory entry {entry['Entry']} has a region filter that does not include {AWS_REGION}. Removing from list.")
                    else:
                        logger.debug(f"Virtual directory entry {entry['Entry']} has a region filter that includes {AWS_REGION}.")
                        entry.pop("regions")
                        filtered_home_directory_details.append(entry)
                else:
                    logger.debug(f"Virtual directory entry {entry['Entry']} has no region filter.")
                    filtered_home_directory_details.append(entry)
            response_data["HomeDirectoryDetails"] = json.dumps(
                filtered_home_directory_details
            )

    # Strip "\n" from Public Key strings. Sometimes they are added unintentionally when copying from terminal
    if len(response_data.get("PublicKeys", [])) > 0:
        for i, key in enumerate(response_data["PublicKeys"]):
            response_data["PublicKeys"][i] = key.replace("\\n", "")

    # An extra check to make sure we've really authenticated, prevent accidental authentication. There should always be either at least 1 public key in response, or 'password' authentication should have been used.
    if (
        len(response_data.get("PublicKeys", [])) < 1
        and event.get("password", "").strip() == ""
    ):
        raise IdpHandlerException(
            "PublicKeys is empty and password was not set. Check user config and authentication module logic."
        )

    logger.debug(f"Response Data after processing with IdP module: {response_data}")

    response_data_str = json.dumps(response_data)
    
    response_variables = {
        "USERNAME": username,
        "AWS_REGION": AWS_REGION,
        "AWS_ACCOUNT": ACCOUNT_ID
    }

    response_data_str = re.sub(r'\{\{(\w+)\}\}', lambda match: response_variables[match.group(1)], response_data_str)

    response_data = json.loads(response_data_str)

    logger.info(f"Completed Response Data: {json.dumps(response_data, default=list)}")

    return response_data
