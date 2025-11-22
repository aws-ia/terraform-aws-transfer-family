import json
import boto3
import re
import os
from urllib.parse import unquote_plus

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 events via EventBridge
    Calls the AgentCore workflow when claim files are uploaded
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse S3 event from EventBridge
        detail = event.get('detail', {})
        bucket = detail.get('bucket', {}).get('name')
        key = unquote_plus(detail.get('object', {}).get('key', ''))
        
        print(f"S3 Event - Bucket: {bucket}, Key: {key}")
        
        # Only process PDF files (claim reports)
        if not key.endswith('.pdf'):
            print(f"Ignoring non-PDF file: {key}")
            return {'statusCode': 200, 'body': 'Ignored non-PDF file'}
        
        # Extract claim folder (e.g., "claim-1" from "submitted-claims/claim-1/car_damage_claim_report.pdf" or "claim-1/car_damage_claim_report.pdf")
        claim_match = re.match(r'^(?:submitted-claims/)?(claim-\d+)/', key)
        if not claim_match:
            print(f"File not in expected claim folder structure: {key}")
            return {'statusCode': 200, 'body': 'File not in claim folder'}
        
        claim_folder = claim_match.group(1)
        
        # Determine if files are in submitted-claims or root
        if key.startswith('submitted-claims/'):
            pdf_key = key
            image_key = f"submitted-claims/{claim_folder}/{claim_folder}.png"
        else:
            pdf_key = key
            image_key = f"{claim_folder}/{claim_folder}.png"
        
        # Check if both PDF and PNG files exist before processing
        s3_client = boto3.client('s3', region_name='us-east-1')
        
        try:
            # Check if PDF exists
            s3_client.head_object(Bucket=bucket, Key=pdf_key)
            print(f"✓ PDF found: {pdf_key}")
            
            # Check if PNG exists
            s3_client.head_object(Bucket=bucket, Key=image_key)
            print(f"✓ PNG found: {image_key}")
            
        except s3_client.exceptions.NoSuchKey as e:
            missing_file = image_key if 'png' in str(e).lower() else pdf_key
            print(f"Missing file: {missing_file}. Waiting for both files to be uploaded.")
            return {
                'statusCode': 200, 
                'body': f'Waiting for both PDF and PNG files. Missing: {missing_file}'
            }
        
        print(f"✓ Both files present. Processing claim: {claim_folder}")
        print(f"PDF: {pdf_key}, Image: {image_key}")
        
        # Move files to submitted-claims/ prefix if not already there
        if not key.startswith('submitted-claims/'):
            submitted_pdf_key = f"submitted-claims/{pdf_key}"
            submitted_image_key = f"submitted-claims/{image_key}"
            
            print(f"Moving files to submitted-claims/ prefix...")
            s3_client.copy_object(
                Bucket=bucket,
                CopySource=f"{bucket}/{pdf_key}",
                Key=submitted_pdf_key
            )
            s3_client.copy_object(
                Bucket=bucket,
                CopySource=f"{bucket}/{image_key}",
                Key=submitted_image_key
            )
            print(f"✓ Files moved to submitted-claims/")
            
            # Delete original files
            s3_client.delete_object(Bucket=bucket, Key=pdf_key)
            s3_client.delete_object(Bucket=bucket, Key=image_key)
            print(f"✓ Original files deleted")
            
            # Update keys to use submitted-claims/ prefix
            pdf_key = submitted_pdf_key
            image_key = submitted_image_key
        
        # Call AgentCore workflow
        result = trigger_workflow(bucket, pdf_key, image_key)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Workflow triggered successfully',
                'claim_folder': claim_folder,
                'result': result
            })
        }
        
    except Exception as e:
        print(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def trigger_workflow(bucket, pdf_key, image_key):
    """Trigger the AgentCore workflow runtime"""
    
    client = boto3.client('bedrock-agentcore', region_name='us-east-1')
    
    # Get workflow ARN from environment variable
    workflow_runtime_arn = os.environ.get('WORKFLOW_RUNTIME_ARN')
    
    if not workflow_runtime_arn:
        raise ValueError("WORKFLOW_RUNTIME_ARN environment variable not set")
    
    payload = {
        "bucket": bucket,
        "pdf_key": pdf_key,
        "image_key": image_key
    }
    
    session_id = f"auto-trigger-{abs(hash(str(payload))):026d}"
    
    print(f"Calling workflow with payload: {payload}")
    
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
