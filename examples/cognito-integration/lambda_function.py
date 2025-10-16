import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.client('dynamodb')
cognito = boto3.client('cognito-idp')
s3 = boto3.client('s3')

def handler(event, context):
    """
    AWS Transfer Family custom identity provider using Cognito
    """
    try:
        # Extract parameters from the event
        username = event.get('username', '')
        password = event.get('password', '')
        protocol = event.get('protocol', 'SFTP')
        source_ip = event.get('sourceIp', '')
        
        logger.info(f"Authentication attempt for user: {username}")
        
        # Get configuration from DynamoDB
        config = get_config_from_dynamodb()
        if not config:
            logger.error("Failed to retrieve configuration from DynamoDB")
            return {}
        
        # Authenticate with Cognito
        auth_result = authenticate_with_cognito(username, password, config)
        if not auth_result:
            logger.warning(f"Authentication failed for user: {username}")
            return {}
        
        # Ensure user directory exists in S3
        ensure_user_directory(username)
        
        # Return successful authentication response
        response = {
            'Role': os.environ.get('SFTP_ROLE_ARN'),
            'HomeDirectory': f"/{os.environ.get('S3_BUCKET')}/{username}",
            'HomeDirectoryType': 'PATH'
        }
        
        logger.info(f"Authentication successful for user: {username}, returning: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Error in authentication: {str(e)}")
        return {}

def ensure_user_directory(username):
    """
    Create user directory in S3 bucket
    """
    try:
        bucket_name = os.environ.get('S3_BUCKET')
        key = f"{username}/"
        
        s3.put_object(Bucket=bucket_name, Key=key)
        logger.info(f"Created directory for user: {username}")
        
    except Exception as e:
        logger.warning(f"Could not create directory for user {username}: {str(e)}")

def get_config_from_dynamodb():
    """
    Retrieve configuration from DynamoDB
    """
    try:
        response = dynamodb.get_item(
            TableName=os.environ.get('DYNAMODB_TABLE'),
            Key={
                'provider': {'S': 'cognito'}
            }
        )
        
        if 'Item' not in response:
            logger.error("Configuration not found in DynamoDB")
            return None
            
        config = response['Item']['config']['M']
        return {
            'cognito_client_id': config['cognito_client_id']['S'],
            'cognito_user_pool_region': config['cognito_user_pool_region']['S'],
            'mfa': config['mfa']['BOOL'],
            'mfa_token_length': int(config['mfa_token_length']['N'])
        }
        
    except Exception as e:
        logger.error(f"Error retrieving config from DynamoDB: {str(e)}")
        return None

def authenticate_with_cognito(username, password, config):
    """
    Authenticate user with Cognito
    """
    try:
        # Get user pool ID from the client ID
        user_pool_id = get_user_pool_id(config['cognito_client_id'])
        if not user_pool_id:
            logger.error("Could not find user pool for client ID")
            return False
        
        # Authenticate user
        response = cognito.admin_initiate_auth(
            UserPoolId=user_pool_id,
            ClientId=config['cognito_client_id'],
            AuthFlow='ADMIN_NO_SRP_AUTH',
            AuthParameters={
                'USERNAME': username,
                'PASSWORD': password
            }
        )
        
        # Check if authentication was successful
        if 'AuthenticationResult' in response:
            logger.info(f"Cognito authentication successful for user: {username}")
            return True
        
        return False
        
    except cognito.exceptions.NotAuthorizedException:
        logger.warning(f"Invalid credentials for user: {username}")
        return False
    except Exception as e:
        logger.error(f"Error authenticating with Cognito: {str(e)}")
        return False

def get_user_pool_id(client_id):
    """
    Get user pool ID from client ID
    """
    try:
        # List all user pools
        paginator = cognito.get_paginator('list_user_pools')
        
        for page in paginator.paginate(MaxResults=50):
            for pool in page['UserPools']:
                # Check if this pool has our client
                try:
                    clients = cognito.list_user_pool_clients(
                        UserPoolId=pool['Id'],
                        MaxResults=50
                    )
                    
                    for client in clients['UserPoolClients']:
                        if client['ClientId'] == client_id:
                            return pool['Id']
                except Exception:
                    continue
        
        return None
        
    except Exception as e:
        logger.error(f"Error finding user pool: {str(e)}")
        return None
