import json
import boto3
import re
import os
import zipfile
import tempfile
from urllib.parse import unquote_plus
from botocore.exceptions import ClientError

# Get region from environment
REGION = os.environ.get('AWS_REGION', 'us-east-1')

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 events via EventBridge
    Extracts ZIP files and calls the AgentCore workflow when claim files are uploaded
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse S3 event from EventBridge
        detail = event.get('detail', {})
        bucket = detail.get('bucket', {}).get('name')
        key = unquote_plus(detail.get('object', {}).get('key', ''))
        
        print(f"S3 Event - Bucket: {bucket}, Key: {key}, Region: {REGION}")
        
        # Only process ZIP files
        if not key.endswith('.zip'):
            print(f"Ignoring non-ZIP file: {key}")
            return {'statusCode': 200, 'body': 'Ignored non-ZIP file'}
        
        # Extract claim folder name from ZIP filename
        # Expected: claim-1.zip, claim-2.zip, etc.
        claim_match = re.match(r'^(?:.*/)?(claim-\d+)\.zip$', key)
        if not claim_match:
            print(f"ZIP file not in expected naming format (claim-N.zip): {key}")
            return {'statusCode': 200, 'body': 'ZIP file not in expected format'}
        
        claim_folder = claim_match.group(1)
        print(f"Processing claim: {claim_folder}")
        
        # Check idempotency - has this claim already been processed?
        s3_client = boto3.client('s3', region_name=REGION)
        
        if is_already_processed(s3_client, bucket, claim_folder):
            print(f"Claim {claim_folder} already processed. Skipping.")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Claim already processed',
                    'claim_folder': claim_folder
                })
            }
        
        # Download and extract ZIP file
        pdf_key, image_key = extract_claim_files(s3_client, bucket, key, claim_folder)
        
        if not pdf_key or not image_key:
            raise ValueError(f"Failed to extract required files from {key}")
        
        print(f"✓ Files extracted - PDF: {pdf_key}, Image: {image_key}")
        
        # Mark as processed before triggering workflow (idempotency)
        mark_as_processed(s3_client, bucket, claim_folder)
        
        # Call AgentCore workflow
        result = trigger_workflow(bucket, pdf_key, image_key)
        
        # Delete the original ZIP file after successful processing
        s3_client.delete_object(Bucket=bucket, Key=key)
        print(f"✓ Original ZIP file deleted: {key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Workflow triggered successfully',
                'claim_folder': claim_folder,
                'pdf_key': pdf_key,
                'image_key': image_key,
                'result': result
            })
        }
        
    except Exception as e:
        print(f"Error processing event: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def is_already_processed(s3_client, bucket, claim_folder):
    """
    Check if claim has already been processed using S3 object metadata
    Looks for a marker file: submitted-claims/{claim_folder}/.processed
    """
    marker_key = f"submitted-claims/{claim_folder}/.processed"
    
    try:
        s3_client.head_object(Bucket=bucket, Key=marker_key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        raise

def mark_as_processed(s3_client, bucket, claim_folder):
    """
    Mark claim as processed by creating a marker file
    """
    marker_key = f"submitted-claims/{claim_folder}/.processed"
    
    s3_client.put_object(
        Bucket=bucket,
        Key=marker_key,
        Body=json.dumps({
            'processed_at': context.aws_request_id if 'context' in globals() else 'unknown',
            'timestamp': str(os.environ.get('AWS_EXECUTION_ENV', 'local'))
        }),
        ContentType='application/json'
    )
    print(f"✓ Marked as processed: {marker_key}")

def extract_claim_files(s3_client, bucket, zip_key, claim_folder):
    """
    Download ZIP file, extract contents, and upload to S3
    Returns: (pdf_key, image_key) tuple
    
    Expected ZIP structure:
    - claim-1.pdf (or any .pdf file)
    - claim-1.png (or any .png/.jpg file)
    """
    
    pdf_key = None
    image_key = None
    
    # Create temporary directory for extraction
    with tempfile.TemporaryDirectory() as temp_dir:
        # Download ZIP file
        zip_path = os.path.join(temp_dir, 'claim.zip')
        print(f"Downloading ZIP: {zip_key}")
        s3_client.download_file(bucket, zip_key, zip_path)
        
        # Extract ZIP file
        print(f"Extracting ZIP file...")
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
        
        # Find PDF and image files
        for root, dirs, files in os.walk(temp_dir):
            for file in files:
                file_lower = file.lower()
                file_path = os.path.join(root, file)
                
                # Skip the ZIP file itself and hidden files
                if file.startswith('.') or file.endswith('.zip'):
                    continue
                
                # Look for PDF
                if file_lower.endswith('.pdf') and not pdf_key:
                    # Upload to submitted-claims/{claim_folder}/{claim_folder}.pdf
                    s3_key = f"submitted-claims/{claim_folder}/{claim_folder}.pdf"
                    print(f"Uploading PDF: {file} -> {s3_key}")
                    s3_client.upload_file(file_path, bucket, s3_key)
                    pdf_key = s3_key
                
                # Look for image (PNG or JPG)
                elif (file_lower.endswith('.png') or file_lower.endswith('.jpg') or file_lower.endswith('.jpeg')) and not image_key:
                    # Upload to submitted-claims/{claim_folder}/{claim_folder}.png
                    # Always use .png extension for consistency
                    s3_key = f"submitted-claims/{claim_folder}/{claim_folder}.png"
                    print(f"Uploading image: {file} -> {s3_key}")
                    s3_client.upload_file(file_path, bucket, s3_key)
                    image_key = s3_key
                
                # Stop if we found both files
                if pdf_key and image_key:
                    break
            
            if pdf_key and image_key:
                break
    
    if not pdf_key:
        raise ValueError(f"No PDF file found in ZIP: {zip_key}")
    if not image_key:
        raise ValueError(f"No image file (PNG/JPG) found in ZIP: {zip_key}")
    
    return pdf_key, image_key

def trigger_workflow(bucket, pdf_key, image_key):
    """Trigger the AgentCore workflow runtime"""
    
    client = boto3.client('bedrock-agentcore', region_name=REGION)
    
    # Get workflow ARN from environment variable
    workflow_runtime_arn = os.environ.get('WORKFLOW_RUNTIME_ARN')
    
    if not workflow_runtime_arn:
        raise ValueError("WORKFLOW_RUNTIME_ARN environment variable not set")
    
    payload = {
        "bucket": bucket,
        "pdf_key": pdf_key,
        "image_key": image_key
    }
    
    # Generate unique session ID based on claim folder
    import hashlib
    claim_id = pdf_key.split('/')[1]  # Extract claim-N from path
    session_id = f"claim-{claim_id}-{hashlib.md5(pdf_key.encode()).hexdigest()[:8]}"
    
    print(f"Calling workflow with payload: {payload}")
    print(f"Session ID: {session_id}")
    
    response = client.invoke_agent_runtime(
        agentRuntimeArn=workflow_runtime_arn,
        runtimeSessionId=session_id,
        payload=json.dumps(payload),
        qualifier="DEFAULT"
    )
    
    # Read response
    response_body = response['response'].read()
    result = json.loads(response_body)
    
    print(f"Workflow result: {result}")
    return result
