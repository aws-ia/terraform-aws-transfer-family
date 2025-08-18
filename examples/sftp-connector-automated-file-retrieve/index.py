import boto3
import os
import json
import logging
import paramiko
import io
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_sftp_credentials(secret_arn):
    """Get SFTP credentials from Secrets Manager"""
    secrets_client = boto3.client('secretsmanager')
    try:
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        secret = json.loads(response['SecretString'])
        return secret
    except Exception as e:
        logger.error(f"Error getting SFTP credentials: {str(e)}")
        raise

def list_directory_files(sftp_endpoint, credentials, directory_path):
    """List all files in the remote SFTP directory"""
    try:
        # Parse hostname and port from endpoint
        if ':' in sftp_endpoint:
            hostname, port = sftp_endpoint.split(':')
            port = int(port)
        else:
            hostname = sftp_endpoint
            port = 22
            
        # Create SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect using credentials
        if 'private_key' in credentials and credentials['private_key']:
            # Use private key authentication
            private_key = paramiko.RSAKey.from_private_key(io.StringIO(credentials['private_key']))
            ssh.connect(hostname, port=port, username=credentials['username'], pkey=private_key)
        else:
            # Use password authentication
            ssh.connect(hostname, port=port, username=credentials['username'], password=credentials['password'])
        
        # Create SFTP client
        sftp = ssh.open_sftp()
        
        # List directory contents
        files = []
        try:
            file_list = sftp.listdir(directory_path)
            for filename in file_list:
                file_path = f"{directory_path.rstrip('/')}/{filename}"
                # Check if it's a file (not directory)
                try:
                    stat = sftp.stat(file_path)
                    if not stat.st_mode & 0o040000:  # Not a directory
                        files.append(file_path)
                except:
                    # If we can't stat it, assume it's a file
                    files.append(file_path)
                    
            logger.info(f"Found {len(files)} files in directory {directory_path}: {files}")
            
        except Exception as e:
            logger.error(f"Error listing directory {directory_path}: {str(e)}")
            
        finally:
            sftp.close()
            ssh.close()
            
        return files
        
    except Exception as e:
        logger.error(f"Error connecting to SFTP server: {str(e)}")
        return []

def handler(event, context):
    try:
        # Initialize AWS clients
        transfer_client = boto3.client('transfer')
        
        # Get environment variables
        connector_id = os.environ['CONNECTOR_ID']
        bucket_name = os.environ['S3_BUCKET_NAME']
        s3_destination_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved').rstrip('/')
        workflow_type = os.environ.get('WORKFLOW_TYPE', 'static')
        source_directory = os.environ.get('SOURCE_DIRECTORY', '/uploads')
        sftp_endpoint = os.environ.get('SFTP_ENDPOINT')
        secret_arn = os.environ.get('SFTP_SECRET_ARN')
        
        # For RETRIEVE operations, LocalDirectoryPath must be /bucket-name/path
        s3_destination_prefix = f'/{bucket_name}/{s3_destination_prefix}'
        
        logger.info(f"Starting file retrieval process for connector: {connector_id}")
        logger.info(f"Workflow type: {workflow_type}")
        
        if workflow_type == 'directory':
            # Directory mode: list files from remote SFTP directory
            logger.info(f"Directory mode: listing files from {source_directory}")
            
            if not secret_arn or not sftp_endpoint:
                raise Exception("SFTP_SECRET_ARN and SFTP_ENDPOINT are required for directory workflow")
                
            credentials = get_sftp_credentials(secret_arn)
            
            # List files in the remote directory
            retrieve_file_paths = list_directory_files(sftp_endpoint, credentials, source_directory)
            
            if not retrieve_file_paths:
                logger.info(f"No files found in directory {source_directory}")
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': f'No files found in directory {source_directory}',
                        'processed_files': 0
                    })
                }
            
        else:
            # Static mode: use predefined file paths (shouldn't reach here in directory workflow)
            logger.error("Static workflow should use EventBridge Scheduler, not Lambda")
            raise Exception("Invalid workflow configuration")
        
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
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File retrieval started successfully',
                'transferId': transfer_id,
                'workflow_type': workflow_type,
                'processed_files': len(retrieve_file_paths),
                'file_paths': retrieve_file_paths
            })
        }
        
    except Exception as e:
        logger.error(f"Error during file retrieval: {str(e)}")
        raise e
