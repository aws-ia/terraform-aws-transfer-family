import boto3
import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def list_directory_files(transfer_client, connector_id, directory_path, output_path):
    """List all files in the remote directory using Transfer Family API"""
    try:
        response = transfer_client.start_directory_listing(
            ConnectorId=connector_id,
            RemoteDirectoryPath=directory_path,
            OutputDirectoryPath=output_path
        )
        
        listing_id = response['ListingId']
        logger.info(f"Directory listing started: {listing_id}")
        
        # Poll for completion
        import time
        max_attempts = 30
        attempt = 0
        
        while attempt < max_attempts:
            describe_response = transfer_client.describe_execution(
                ExecutionId=listing_id
            )
            
            status = describe_response['Execution']['Status']
            logger.info(f"Listing status: {status}")
            
            if status == 'COMPLETED':
                # Get the listing results
                outputs = describe_response['Execution'].get('Results', {})
                files = []
                
                if 'Steps' in outputs:
                    for step in outputs['Steps']:
                        if step.get('StepType') == 'LIST' and 'Outputs' in step:
                            step_outputs = json.loads(step['Outputs'])
                            if 'FilePaths' in step_outputs:
                                files.extend(step_outputs['FilePaths'])
                
                logger.info(f"Found {len(files)} files: {files}")
                return files
                
            elif status in ['FAILED', 'EXCEPTION']:
                error_msg = describe_response['Execution'].get('Error', {}).get('Message', 'Unknown error')
                logger.error(f"Directory listing failed: {error_msg}")
                return []
                
            time.sleep(2)
            attempt += 1
            
        logger.warning("Directory listing timed out")
        return []
        
    except Exception as e:
        logger.error(f"Error listing directory: {str(e)}")
        return []

def handler(event, context):
    try:
        transfer_client = boto3.client('transfer')
        dynamodb = boto3.client('dynamodb')
        
        connector_id = os.environ['CONNECTOR_ID']
        bucket_name = os.environ['S3_BUCKET_NAME']
        s3_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved').rstrip('/')
        source_directory = os.environ.get('SOURCE_DIRECTORY', '/uploads')
        table_name = os.environ.get('DYNAMODB_TABLE_NAME')
        
        s3_destination = f'/{bucket_name}/{s3_prefix}'
        
        logger.info(f"Directory retrieval from: {source_directory}")
        
        # List directory using Transfer Family API
        file_paths = list_directory_files(transfer_client, connector_id, source_directory, s3_destination)
        
        if not file_paths:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'No files found in {source_directory}',
                    'files_found': 0
                })
            }
        
        # Start transfer for all discovered files
        transfer_response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=file_paths,
            LocalDirectoryPath=s3_destination
        )
        
        transfer_id = transfer_response['TransferId']
        logger.info(f"Transfer started: {transfer_id}")
        
        # Update DynamoDB status to 'in_progress' for transferred files
        if table_name:
            for file_path in file_paths:
                try:
                    dynamodb.update_item(
                        TableName=table_name,
                        Key={'file_path': {'S': file_path}},
                        UpdateExpression='SET #status = :status, transfer_id = :transfer_id',
                        ExpressionAttributeNames={'#status': 'status'},
                        ExpressionAttributeValues={
                            ':status': {'S': 'in_progress'},
                            ':transfer_id': {'S': transfer_id}
                        }
                    )
                except Exception as e:
                    logger.warning(f"Failed to update DynamoDB for {file_path}: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Directory retrieval started',
                'transferId': transfer_id,
                'files_found': len(file_paths),
                'file_paths': file_paths
            })
        }
        
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        raise e
