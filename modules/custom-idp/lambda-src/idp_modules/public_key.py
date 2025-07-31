import logging
import os
from idp_modules import util
from datetime import datetime, timezone

from aws_lambda_powertools import Tracer

tracer = Tracer()

logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


class PublicKeyIdpModuleError(util.IdpModuleError):
    """Used to raise module-specific exceptions"""

    pass


@tracer.capture_method
def handle_auth(
    event,
    parsed_username,
    user_record,
    identity_provider_record,
    response_data,
    authn_method,
):
    logger.debug(f"User record: {user_record}")

    if not event["protocol"] == "SFTP":
        raise PublicKeyIdpModuleError(
            f"Protocol {event['protocol']} does not support public key auth."
        )

    user_record_config = user_record["config"]

    if not "PublicKeys" in response_data:
        if not "PublicKeys" in user_record_config:
            raise PublicKeyIdpModuleError(
                f"No public keys defined for user in config of user {user_record['user']}."
            )
        else:
            logger.info(f'PublicKeys found in config for user {user_record["user"]}')
            logger.debug(f'PublicKeys: {user_record_config["PublicKeys"]}')
            logger.debug(f'Type: {type(user_record_config["PublicKeys"])}')
            response_data.setdefault(
                "PublicKeys", []
            ) 
            if type(user_record_config["PublicKeys"]) == str:
                logger.debug(f'Adding {user_record_config["PublicKeys"]} to PublicKeys List.')
                response_data["PublicKeys"] = [user_record_config["PublicKeys"]] 
            elif type(user_record_config["PublicKeys"]) == set:
                logger.debug(f'Converting set of public keys to list.')
                response_data["PublicKeys"] = list(user_record_config["PublicKeys"])
            elif type(user_record_config["PublicKeys"]) == list:
                for item in user_record_config["PublicKeys"]:
                    if type(item) == dict:
                        if "PublicKey" in item:
                            if not "Expires" in item or datetime.fromisoformat(item["Expires"]) > datetime.now(timezone.utc):
                                    logger.debug(f'Public key {item["PublicKey"]} has not expired for user {user_record["user"]}.')
                                    response_data["PublicKeys"].append(item["PublicKey"])
                            else:
                                logger.warn(f'Public key {item["PublicKey"]} has expired for user {user_record["user"]}.')
                        
                    elif type(item) == str:
                        logger.debug(f'Adding public key {item} to list.')
                        response_data["PublicKeys"].append(item)
                    else:
                        logger.warn(f'Invalid public key type {type(item)} in "PublicKeys" value for user {user_record["user"]}.')

    return response_data