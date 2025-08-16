import boto3
import os
import json
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
        bucket_name = os.environ['S3_BUCKET_NAME']
        s3_destination_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved').rstrip('/')
        # For RETRIEVE operations, LocalDirectoryPath must be /bucket-name/path
        s3_destination_prefix = f'/{bucket_name}/{s3_destination_prefix}'
        
        # Get DynamoDB table
        table = dynamodb.Table(table_name)
        
        logger.info(f"Starting file retrieval process for connector: {connector_id}")
        
        # Scan for pending files (since we don't have GSI)
        logger.info(f"Scanning table {table_name} for pending files")
        response = table.scan(
            FilterExpression='#status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': 'pending'}
        )
        
        logger.info(f"DynamoDB scan response: {response}")
        pending_files = response.get('Items', [])
        logger.info(f"Pending files found: {len(pending_files)}")
        
        if not pending_files:
            # Check for in_progress files and their transfer status
            all_response = table.scan()
            all_items = all_response.get('Items', [])
            logger.info(f"All items in table: {all_items}")
            
            # Reset all in_progress items to pending for retry
            for item in all_items:
                if item.get('status') == 'in_progress':
                    table.update_item(
                        Key={'file_path': item['file_path']},
                        UpdateExpression='SET #status = :status',
                        ExpressionAttributeNames={'#status': 'status'},
                        ExpressionAttributeValues={':status': 'pending'}
                    )
                    logger.info(f"Reset {item['file_path']} to pending status")
            
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
        
        logger.info(f"Found {len(retrieve_file_paths)} files to retrieve: {retrieve_file_paths}")
        logger.info(f"Using LocalDirectoryPath: {s3_destination_prefix}")
        
        # Start file transfer using retrieve operation
        transfer_response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=retrieve_file_paths,
            LocalDirectoryPath=s3_destination_prefix
        )
        
        transfer_id = transfer_response['TransferId']
        logger.info(f"File retrieval started successfully: {transfer_id}")
        
        logger.info(f"Transfer started with ID: {transfer_id}")
        
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
