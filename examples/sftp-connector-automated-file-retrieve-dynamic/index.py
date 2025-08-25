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

def lambda_handler(event, context):
    try:
        transfer_client = boto3.client('transfer')
        
        connector_id = os.environ['CONNECTOR_ID']
        bucket_name = os.environ['S3_BUCKET']
        s3_prefix = os.environ.get('S3_PREFIX', 'retrieved').rstrip('/')
        source_directory = os.environ.get('SOURCE_DIRECTORY', '/uploads')
        
        s3_destination = f'/{bucket_name}/{s3_prefix}'
        
        logger.info(f"Directory retrieval from: {source_directory}")
        
        # Start directory listing
        response = transfer_client.start_directory_listing(
            ConnectorId=connector_id,
            RemoteDirectoryPath=source_directory,
            OutputDirectoryPath=s3_destination
        )
        
        listing_id = response['ListingId']
        logger.info(f"Directory listing started: {listing_id}")
        
        # Wait a moment for listing to complete
        import time
        time.sleep(5)
        
        # Check if listing completed and get file paths from S3
        s3_client = boto3.client('s3')
        
        # List objects in the destination to find the listing file
        list_response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix=f"{s3_prefix}/{connector_id}-{listing_id}.json"
        )
        
        if 'Contents' not in list_response:
            logger.warning("Directory listing file not found yet")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Directory listing in progress'})
            }
        
        # Get the listing file
        listing_key = list_response['Contents'][0]['Key']
        listing_obj = s3_client.get_object(Bucket=bucket_name, Key=listing_key)
        listing_data = json.loads(listing_obj['Body'].read().decode('utf-8'))
        
        # Extract file paths
        file_paths = [file_info['filePath'] for file_info in listing_data.get('files', [])]
        
        if not file_paths:
            logger.info("No files found in directory listing")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No files found', 'files_found': 0})
            }
        
        logger.info(f"Found {len(file_paths)} files: {file_paths}")
        
        # Start file transfer for discovered files
        transfer_response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=file_paths,
            LocalDirectoryPath=s3_destination
        )
        
        transfer_id = transfer_response['TransferId']
        logger.info(f"File transfer started: {transfer_id}")
        
        # Clean up the directory listing JSON file
        try:
            s3_client.delete_object(Bucket=bucket_name, Key=listing_key)
            logger.info(f"Cleaned up metadata file: {listing_key}")
        except Exception as e:
            logger.warning(f"Failed to delete metadata file: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Dynamic file retrieval started',
                'transferId': transfer_id,
                'files_found': len(file_paths),
                'file_paths': file_paths
            })
        }
        
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        raise e
