import json
import logging
import os
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
USERS_TABLE = os.environ["USERS_TABLE"]
IDENTITY_PROVIDERS_TABLE = os.environ["IDENTITY_PROVIDERS_TABLE"]

# DynamoDB resources
dynamodb = boto3.resource("dynamodb")
users_table = dynamodb.Table(USERS_TABLE)
idp_table = dynamodb.Table(IDENTITY_PROVIDERS_TABLE)

# Cognito client
cognito_client = boto3.client("cognito-idp")

def lambda_handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")
    
    username = event.get("username", "")
    password = event.get("password", "")
    server_id = event.get("serverId", "")
    
    if not username or not password:
        logger.error("Missing username or password")
        return {}
    
    try:
        # Get identity provider config
        idp_response = idp_table.get_item(Key={"ServerId": server_id})
        if "Item" not in idp_response:
            logger.error(f"No identity provider found for server {server_id}")
            return {}
        
        idp_config = idp_response["Item"]["config"]
        user_pool_id = idp_config["user_pool_id"]
        client_id = idp_config["client_id"]
        
        # Authenticate with Cognito
        auth_response = cognito_client.admin_initiate_auth(
            UserPoolId=user_pool_id,
            ClientId=client_id,
            AuthFlow="ADMIN_NO_SRP_AUTH",
            AuthParameters={
                "USERNAME": username,
                "PASSWORD": password
            }
        )
        
        if "AuthenticationResult" not in auth_response:
            logger.error(f"Authentication failed for user {username}")
            return {}
        
        logger.info(f"Authentication for user {username} successful")
        
        # Get user configuration from DynamoDB
        user_response = users_table.get_item(Key={"Username": username})
        if "Item" not in user_response:
            logger.error(f"No user configuration found for {username}")
            return {}
        
        user_config = user_response["Item"]
        
        # Return Transfer Family response
        response = {
            "Role": user_config.get("Role", ""),
            "Policy": user_config.get("Policy", ""),
            "HomeDirectory": user_config.get("HomeDirectory", f"/{username}")
        }
        
        logger.info(f"Returning response: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Error processing authentication: {str(e)}")
        return {}
