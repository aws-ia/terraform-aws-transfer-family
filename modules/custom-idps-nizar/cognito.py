import logging
import os
import boto3
from idp_modules import util
from aws_lambda_powertools import Tracer

tracer = Tracer()

logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


class CognitoIdpModuleError(util.IdpModuleError):
    """Used to raise module-specific exceptions"""

    pass

client = boto3.client('cognito-idp')

@tracer.capture_method
def handle_auth(
    event,
    parsed_username,
    user_record,
    identity_provider_record,
    response_data,
    authn_method,
):
    
    if authn_method == util.AuthenticationMethod.PUBLIC_KEY:
        raise CognitoIdpModuleError("This provider does not support public key auth.")    
    
    logger.debug(f"User record: {user_record}")


    identity_provider_config = identity_provider_record["config"]
    cognito_client_id = identity_provider_config["cognito_client_id"]
    cognito_user_pool_region = identity_provider_config.get("cognito_user_pool_region", os.environ.get('AWS_REGION', os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')))
    cognito_mfa = identity_provider_record["config"].get("mfa", False)
    cognito_mfa_token_length = int(
        identity_provider_record["config"].get("mfa_token_length", 6)
    )
    password = event["password"]
    
    if cognito_mfa:
        logger.info(
            f"MFA enabled, extracting token code from last {cognito_mfa_token_length} characters of provided password."
        )
        mfa_token = password[-cognito_mfa_token_length:]
        password = password[:-cognito_mfa_token_length]
    else:
        mfa_token = None

    client = boto3.client('cognito-idp', region_name=cognito_user_pool_region)

    logger.info(f"Authenticating {parsed_username} with client id {cognito_client_id} in region {cognito_user_pool_region}")

    response = client.initiate_auth(
        AuthFlow='USER_PASSWORD_AUTH',
        AuthParameters={
            'USERNAME': parsed_username,
            'PASSWORD': password
        },
        ClientId=cognito_client_id, 
        UserContextData = {
            'IpAddress': event["sourceIp"]
        }
    )

    logger.debug(f"Cognito response: {response}")

    if response.get("AuthenticationResult", None) is None:
        if "ChallengeName" in response:
            if cognito_mfa is None:
                logger.error(
                    f"Cognito indicated that MFA is required for this user {parsed_username} but no MFA token was provided. Verify that MFA has been enabled in the IdP config."
                )                
                raise CognitoIdpModuleError("MFA required but not configured for this user.")
            elif response["ChallengeName"] == "SOFTWARE_TOKEN_MFA":
                logger.info(f"Responding to MFA challenge with token.")
                mfa_response = client.respond_to_auth_challenge(
                    ClientId=cognito_client_id,
                    ChallengeName='SOFTWARE_TOKEN_MFA',
                    Session=response["Session"],
                    ChallengeResponses={
                        'USERNAME': parsed_username,
                        'SOFTWARE_TOKEN_MFA_CODE': mfa_token
                    }
                )
                logger.debug(f"Cognito response: {mfa_response}")
                if mfa_response.get("AuthenticationResult", None) is None:
                    raise CognitoIdpModuleError("Authentication failed. AuthenticationResult was not returned by Cognito RespondToAuthChallenge.")
                else: 
                    logger.info(f"MFA authentication for user {parsed_username} successful.")
            else: 
                logger.error(
                    f"Unsupported challenge type {response['ChallengeName']}."
                )                
                raise CognitoIdpModuleError("Unsupported challenge type {response['ChallengeName']}. SOFTWARE_TOKEN_MFA is the only supported challenge type.")                
        else:
            raise CognitoIdpModuleError("Authentication failed. AuthenticationResult was not returned by Cognito InitiateAuth.")
    else:
        logger.info(f"Authentication for user {parsed_username} successful.")
    
    return response_data
