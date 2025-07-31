import logging
import os
import json
import urllib
import re
import msal
from idp_modules import util
from aws_lambda_powertools import Tracer

tracer = Tracer()

logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())

class EntraIdpModuleError(util.IdpModuleError):
    """Used to raise module-specific exceptions"""
    pass

secret_cache = {}

@tracer.capture_method
def entra_authenticate(client_id, client_secret, authority_url, username, password, scopes):
    app = msal.ClientApplication(
        client_id=client_id, 
        client_credential=client_secret,
        authority=authority_url
    )
    logger.debug(f"app: {app}")

    result = app.acquire_token_by_username_password(
        username=username,
        password=password,
        scopes=scopes
    )
    logger.debug(f"Authentication result: {result}")

    if "access_token" not in result:
        error_description = result.get("error_description", "Unknown error")
        logger.error(f"Authentication failure: User: {username}; Error: {error_description}")
        raise EntraIdpModuleError(f"Authentication failure: User: {username}; Error: {error_description}")

    return result

@tracer.capture_method
def handle_auth(event, parsed_username, user_record, identity_provider_record, response_data, authn_method):
    logger.debug(f"User record: {user_record}")

    if authn_method == util.AuthenticationMethod.PUBLIC_KEY:
        raise EntraIdpModuleError("This provider does not support public key auth.")

    entra_config = identity_provider_record["config"]
    entra_app_client_id = entra_config["client_id"]
    entra_app_secret_arn = entra_config.get(
        "app_secret_arn", None
    )
    entra_authority_url = entra_config.get("authority_url", "https://login.microsoftonline.com/organizations")

    scopes = entra_config.get("scopes", ["https://graph.microsoft.com/.default"])
    password = event["password"]

    entra_app_secret = util.fetch_secret_cache(secret_cache, entra_app_secret_arn)

    logger.info(f"Attempting authentication with Microsoft Entra")
    auth_result = entra_authenticate(
        client_id=entra_app_client_id, 
        client_secret=entra_app_secret, 
        authority_url=entra_authority_url, 
        username=parsed_username, 
        password=password, 
        scopes=scopes
    )
    if auth_result.get("access_token", None) is None:
        raise EntraIdpModuleError("Authentication failed. Access token was not returned by Entra Auth.")
    else:
        logger.info(f"Authentication of {parsed_username} was successful")
 

    return response_data