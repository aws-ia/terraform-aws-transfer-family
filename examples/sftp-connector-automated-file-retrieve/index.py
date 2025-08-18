import boto3
import os
import json
import logging
import paramiko
import io

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
        # Parse hostname and port
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
        if 'PrivateKey' in credentials and credentials['PrivateKey']:
            private_key = paramiko.RSAKey.from_private_key(io.StringIO(credentials['PrivateKey']))
            ssh.connect(hostname, port=port, username=credentials['Username'], pkey=private_key)
        else:
            ssh.connect(hostname, port=port, username=credentials['Username'], password=credentials.get('Password', ''))
        
        # Create SFTP client
        sftp = ssh.open_sftp()
        
        # List directory contents
        files = []
        directories = []
        try:
            file_list = sftp.listdir(directory_path)
            logger.info(f"Raw directory listing: {file_list}")
            
            for filename in file_list:
                file_path = f"{directory_path.rstrip('/')}/{filename}"
                # Check if it's a file (not directory)
                try:
                    stat = sftp.stat(file_path)
                    if stat.st_mode & 0o040000:  # Is a directory
                        directories.append(filename)
                        logger.info(f"Found directory: {filename}")
                    else:
                        files.append(file_path)
                        logger.info(f"Found file: {file_path}")
                except Exception as e:
                    logger.warning(f"Could not stat {file_path}: {str(e)}")
                    files.append(file_path)  # Assume it's a file
                    
            logger.info(f"Found {len(files)} files and {len(directories)} directories")
            logger.info(f"Files: {files}")
            logger.info(f"Directories: {directories}")
            
        finally:
            sftp.close()
            ssh.close()
            
        return files
        
    except Exception as e:
        logger.error(f"Error connecting to SFTP: {str(e)}")
        return []

def handler(event, context):
    try:
        transfer_client = boto3.client('transfer')
        
        connector_id = os.environ['CONNECTOR_ID']
        bucket_name = os.environ['S3_BUCKET_NAME']
        s3_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved').rstrip('/')
        source_directory = os.environ.get('SOURCE_DIRECTORY', '/uploads')
        sftp_endpoint = os.environ.get('SFTP_ENDPOINT')
        secret_arn = os.environ.get('SFTP_SECRET_ARN')
        
        s3_destination = f'/{bucket_name}/{s3_prefix}'
        
        logger.info(f"Directory retrieval from: {source_directory}")
        
        if not secret_arn or not sftp_endpoint:
            raise Exception("SFTP_SECRET_ARN and SFTP_ENDPOINT required")
            
        # Get credentials and list directory
        credentials = get_sftp_credentials(secret_arn)
        file_paths = list_directory_files(sftp_endpoint, credentials, source_directory)
        
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
