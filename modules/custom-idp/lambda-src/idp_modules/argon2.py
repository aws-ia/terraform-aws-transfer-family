import logging
import os
from aws_lambda_powertools import Tracer

tracer = Tracer()
from idp_modules import util
import argon2



logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


class Argon2IdpModuleError(util.IdpModuleError):
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

    if authn_method != util.AuthenticationMethod.PASSWORD:
        raise Argon2IdpModuleError(
            "Password not specified, this provider does not support public key auth."
        )
    user_record_config = user_record["config"]
    hashed_password = user_record_config.get("argon2_hash", "")
    logger.debug(f"Hashed password: {hashed_password}")

    if hashed_password.strip() == "":
        raise Argon2IdpModuleError(
            f"No argon2_password defined in record for user {parsed_username}."
        )

    hasher = argon2.PasswordHasher()
    # Throws an exception if password/hash is incorrect
    hasher.verify(hashed_password, event["password"])

    logger.info(f"User {parsed_username} authenticated successfully.")

    return response_data