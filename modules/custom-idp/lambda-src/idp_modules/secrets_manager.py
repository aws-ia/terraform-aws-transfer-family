import ast
import json
import logging
from idp_modules import util
from aws_lambda_powertools import Tracer

tracer = Tracer()


class SecretsManagerIdpModuleError(util.IdpModuleError):
    """Used to raise module-specific exceptions"""

    pass


logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


@tracer.capture_method
def handle_auth(
    event,
    parsed_username,
    user_record,
    identity_provider_record,
    response_data,
    authn_method,
):
    logger.debug(user_record)

    if authn_method == util.AuthenticationMethod.PASSWORD:
        input_password = event["password"]
    else:
        logger.info("No password, checking for SSH key")
        input_password = ""

    secret_prefix = identity_provider_record.get("config", {}).get(
        "secret_prefix", "SFTP/"
    )

    # Lookup user's secret which can contain the password or SSH public keys
    logger.info(f"Fetching secret {secret_prefix}{parsed_username}")
    secret = util.get_secret(f"{secret_prefix}{parsed_username}")
    if secret != None:
        secret_dict = json.loads(secret)
        logger.debug(
            {
                i: secret_dict[i]
                for i in secret_dict
                if i not in ["Password", "PublicKey"]
            }
        )
    else:
        raise SecretsManagerIdpModuleError("No secrets data returned, cannot proceed.")

    if authn_method == util.AuthenticationMethod.PASSWORD:
        if "Password" in secret_dict:
            resp_password = secret_dict["Password"]
        else:
            logger.error(
                "Unable to authenticate user - No field match in Secret for password"
            )
            return {}

        if resp_password != input_password:
            logger.error(
                "Unable to authenticate user - Incoming password does not match stored value"
            )
            return {}
    else:
        # SSH Public Key Auth Flow - The incoming password was empty so we are trying ssh auth and need to return the public key data if we have it
        if "PublicKeys" in secret_dict:
            logger.debug(f"PublicKeys: {secret_dict['PublicKeys']}")
            keys_list = secret_dict["PublicKeys"]
            if not type(keys_list) == list:
                keys_list = ast.literal_eval(keys_list)
            logger.debug(f"Keys dict: {keys_list}")
            response_data["PublicKeys"] = keys_list
        else:
            logger.info(
                f"No PublicKeys found in secret, attempting to retrieve from {secret_prefix}{parsed_username}/keys"
            )
            keys_secret = util.get_secret(f"{secret_prefix}{parsed_username}/keys")
            if keys_secret != None:
                keys_secret_dict = json.loads(keys_secret)
                if "PublicKeys" in keys_secret_dict:
                    keys_list = keys_secret_dict["PublicKeys"]
                    if not type(keys_list) == list:
                        keys_list = ast.literal_eval(keys_list)
                    logger.debug(f"Keys dict: {keys_list}")
                    response_data["PublicKeys"] = keys_list
                else:
                    raise SecretsManagerIdpModuleError(
                        "Unable to authenticate user - No public keys found in keys secret"
                    )
            else:
                raise SecretsManagerIdpModuleError(
                    "Unable to authenticate user - No public keys found"
                )

    return response_data