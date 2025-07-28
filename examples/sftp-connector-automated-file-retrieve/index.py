import json
import boto3
import os
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    try:
        # Initialize AWS clients
        transfer_client = boto3.client('transfer')
        dynamodb = boto3.resource('dynamodb')
        
        # Get environment variables
        connector_id = os.environ['CONNECTOR_ID']
        table_name = os.environ['DYNAMODB_TABLE_NAME']
        s3_destination_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved/')
        s3_destination_bucket = os.environ['S3_DESTINATION_BUCKET']
        
        # Get DynamoDB table
        table = dynamodb.Table(table_name)
        
        logger.info(f"Starting file retrieval process for connector: {connector_id}")
        
        # Query for pending files
        response = table.query(
            IndexName='status-index',
            KeyConditionExpression='#status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': 'pending'}
        )
        
        pending_files = response.get('Items', [])
        
        if not pending_files:
            logger.info("No pending files found for retrieval")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No pending files found for retrieval',
                    'processed_files': 0
                })
            }
        
        # Extract file paths for retrieval
        retrieve_file_paths = [item['file_path'] for item in pending_files]
        
        # Get the local directory path from the first file (assuming all files use the same destination)
        local_directory_path = pending_files[0]['local_directory_path']
        
        logger.info(f"Found {len(retrieve_file_paths)} files to retrieve: {retrieve_file_paths}")
        logger.info(f"Using local directory path: {local_directory_path}")
        
        # Start file transfer using retrieve operation
        # LocalDirectoryPath format: /bucket-name/path (based on workshop example)
        transfer_response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=retrieve_file_paths,
            LocalDirectoryPath=f"/{s3_destination_bucket}{local_directory_path}"
        )
        
        transfer_id = transfer_response['TransferId']
        logger.info(f"File retrieval started successfully: {transfer_id}")
        
        # Update status of processed files to 'in_progress'
        for file_path in retrieve_file_paths:
            try:
                table.update_item(
                    Key={'file_path': file_path},
                    UpdateExpression='SET #status = :status, transfer_id = :transfer_id, updated_at = :updated_at',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':status': 'in_progress',
                        ':transfer_id': transfer_id,
                        ':updated_at': context.aws_request_id
                    }
                )
            except ClientError as e:
                logger.error(f"Error updating status for {file_path}: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File retrieval started successfully',
                'transferId': transfer_id,
                'processed_files': len(retrieve_file_paths),
                'file_paths': retrieve_file_paths
            })
        }
        
    except Exception as e:
        logger.error(f"Error during file retrieval: {str(e)}")
        raise e
