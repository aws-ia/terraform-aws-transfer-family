import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    try:
        # Initialize Transfer Family client
        transfer_client = boto3.client('transfer')
        
        # Extract S3 event details
        bucket = event['detail']['bucket']['name']
        key = event['detail']['object']['key']
        
        # Get environment variables
        connector_id = os.environ['CONNECTOR_ID']
        remote_directory_path = os.environ.get('REMOTE_DIRECTORY_PATH', '/')
        
        logger.info(f"Starting file transfer for s3://{bucket}/{key}")
        
        # Start file transfer
        response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            SendFilePaths=[f"/{bucket}/{key}"],
            RemoteDirectoryPath=remote_directory_path
        )
        
        logger.info(f"File transfer started successfully: {response['TransferId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File transfer started successfully',
                'transferId': response['TransferId']
            })
        }
        
    except Exception as e:
        logger.error(f"Error starting file transfer: {str(e)}")
        raise e
