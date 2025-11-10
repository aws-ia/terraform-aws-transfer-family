import importlib
import ipaddress
import json
import logging
import os
import re

import boto3
import botocore
from boto3.dynamodb.conditions import Key

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

os.environ["AWS_STS_REGIONAL_ENDPOINTS"] = "regional"

AWS_REGION = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", ""))

USERS_TABLE_ID = os.environ["USERS_TABLE"]
IDENTITY_PROVIDERS_TABLE_ID = os.environ["IDENTITY_PROVIDERS_TABLE"]
USER_NAME_DELIMITER = os.environ["USER_NAME_DELIMITER"]

boto3_config = botocore.config.Config(
    region_name=AWS_REGION,
    retries={'max_attempts': 3, 'mode': 'standard'}
)

ACCOUNT_ID = boto3.client('sts', config=boto3_config).get_caller_identity().get('Account')
USERS_TABLE = boto3.resource("dynamodb", config=boto3_config).Table(USERS_TABLE_ID)
IDENTITY_PROVIDERS_TABLE = boto3.resource("dynamodb", config=boto3_config).Table(IDENTITY_PROVIDERS_TABLE_ID)

class IdpHandlerException(Exception):
    pass

def ip_in_cidr_list(ip_address, cidr_list):
    for cidr in cidr_list:
        logger.debug("Checking Allowed IP CIDR: {}".format(cidr))
        network = ipaddress.ip_network(cidr)
        if ipaddress.ip_address(ip_address) in network:
            logger.info("Matched {} to IP CIDR {}".format(ip_address, cidr))
            return True
        else:
            logger.debug("Source IP {} doesn't match IP CIDR {}".format(ip_address, cidr))
    return False

def lambda_handler(event, context):
    response_data = {}

    logger.info({i: event[i] for i in event if i not in ["password"]})

    if "username" not in event or "serverId" not in event:
        raise IdpHandlerException("Incoming username or serverId missing  - Unexpected")

    input_username = event["username"].lower()
    logger.info(f"Username: {input_username}, ServerId: {event['serverId']}")

    # Parse the username to get user and identity provider (if specified)
    parsed_username = input_username.split(USER_NAME_DELIMITER)

    if 1 < len(parsed_username):
        if USER_NAME_DELIMITER == "@" or USER_NAME_DELIMITER == "@@":
            username = USER_NAME_DELIMITER.join(parsed_username[:-1])
            identity_provider = parsed_username[-1]
        else:
            username = USER_NAME_DELIMITER.join(parsed_username[1:])
            identity_provider = parsed_username[0]
    else:
        username = parsed_username[0]
        identity_provider = None

    logger.info(f"Parsed username and IdP: Username: {username} IDP: {identity_provider}")
    
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
        logger.info(f"Record for user {username} identity provider {identity_provider} not found, retrieving default user record")
        user_record = USERS_TABLE.query(
            KeyConditionExpression=Key("user").eq("user1")
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
            raise IdpHandlerException(f"Source IP {source_ip} is not allowed to connect.")

    # Lookup identity provider config
    identity_provider = user_record.get("identity_provider_key", "$default$")
    logger.info(f"Fetching identity provider record for {identity_provider}")
    identity_provider_record = IDENTITY_PROVIDERS_TABLE.get_item(
        Key={"provider": identity_provider}
    ).get("Item", None)
    logger.debug(f"identity_provider_record: {identity_provider_record}")
    
    if identity_provider_record is None:
        raise IdpHandlerException(f"Identity provider {identity_provider} is not defined in the table {IDENTITY_PROVIDERS_TABLE}.")
    
    if identity_provider_record.get('disabled', False):
        raise IdpHandlerException(f"Identity provider {identity_provider} is disabled.")

    # Check IP allow list for IdP
    identity_provider_ipv4_allow_list = identity_provider_record.get("ipv4_allow_list", "")
    logger.debug(f"IPv4 Allow List: {identity_provider_ipv4_allow_list}")
    if not identity_provider_ipv4_allow_list or identity_provider_ipv4_allow_list == "":
        logger.info("No identity provider IPv4 allow list is present, skipping check.")
    else:
        if not ip_in_cidr_list(source_ip, identity_provider_ipv4_allow_list):
            raise IdpHandlerException(f"Source IP {source_ip} is not allowed to connect.")

    # Merge AWS transfer session values from identity provider and user records
    user_record.setdefault("config", {})
    identity_provider_record.setdefault("config", {})

    if "Role" in user_record["config"]:
        response_data["Role"] = user_record["config"]["Role"]
        logger.info(f"Using Role value {user_record['config']['Role']} from user record for user {input_username}")
    elif "Role" in identity_provider_record["config"]:
        logger.info(f"Using role value {identity_provider_record['config']['Role']} from identity provider record {identity_provider} for user {input_username}")
        response_data["Role"] = identity_provider_record["config"]["Role"]
    else:
        logger.warning(f"Role arn not found in user record for {input_username} or identity provider record {identity_provider}.")

    if "Policy" in user_record["config"]:
        logger.info(f"Using Policy value from user record for user {input_username}")
        response_data["Policy"] = user_record["config"]["Policy"]
    elif "Policy" in identity_provider_record["config"]:
        logger.info(f"Using Policy value from identity provider record {identity_provider} for user {input_username}")
        response_data["Policy"] = identity_provider_record["config"]["Policy"]

    if "HomeDirectoryDetails" in user_record["config"]:
        logger.info(f"HomeDirectoryDetails found in record for user {input_username}")
        response_data["HomeDirectoryDetails"] = user_record["config"]["HomeDirectoryDetails"]
        response_data["HomeDirectoryType"] = "LOGICAL"
    elif "HomeDirectory" in user_record["config"]:
        logger.info(f"HomeDirectory found for user {input_username}")
        response_data["HomeDirectory"] = user_record["config"]["HomeDirectory"]
        response_data["HomeDirectoryType"] = "PATH"
    elif "HomeDirectoryDetails" in identity_provider_record["config"]:
        logger.info(f"HomeDirectoryDetails found in identity provider record {identity_provider}")
        response_data["HomeDirectoryDetails"] = identity_provider_record["config"]["HomeDirectoryDetails"]
        response_data["HomeDirectoryType"] = "LOGICAL"
    elif "HomeDirectory" in identity_provider_record["config"]:
        logger.info(f"HomeDirectory found in identity provider record {identity_provider}")
        response_data["HomeDirectory"] = identity_provider_record["config"]["HomeDirectory"]
        response_data["HomeDirectoryType"] = "PATH"

    if "PosixProfile" in user_record["config"]:
        logger.info(f"Using PosixProfile value from user record for user {input_username}")
        response_data["PosixProfile"] = user_record["config"]["PosixProfile"]
    elif "PosixProfile" in identity_provider_record["config"]:
        logger.info(f"Using PosixProfile value from identity provider record {identity_provider}")
        response_data["PosixProfile"] = identity_provider_record["config"]["PosixProfile"]

    logger.debug(f"Response Data before processing with IdP module: {response_data}")

    if event.get("password", "").strip() == "":
        logger.info(f"No password provided, performing public key auth.")   
        # Would handle public key auth here
        raise IdpHandlerException("Public key authentication not implemented in this example")
    else:
        logger.info(f"Password provided, performing password auth.")
        # Load the cognito module and perform authentication
        import cognito
        response_data = cognito.handle_auth(
            event=event,
            parsed_username=username,
            user_record=user_record,
            identity_provider_record=identity_provider_record,
            response_data=response_data,
            authn_method="password",
        )

    # HomeDirectoryDetails must be a stringified list
    if "HomeDirectoryDetails" in response_data:
        if type(response_data["HomeDirectoryDetails"]) == list:
            response_data["HomeDirectoryDetails"] = json.dumps(response_data["HomeDirectoryDetails"])

    logger.info(f"Completed Response Data: {json.dumps(response_data, default=list)}")

    return response_data
