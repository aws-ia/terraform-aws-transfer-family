"""
Summary Report Agent using STRANDS framework
Generates comprehensive claim processing summary reports
"""

import os
import json
import logging
import boto3
from datetime import datetime
from strands import Agent, tool
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands.models import BedrockModel

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('summary-report-agent')

# Initialize the BedrockAgentCoreApp
app = BedrockAgentCoreApp()

# Initialize AWS clients
s3_client = boto3.client('s3', region_name=os.environ.get('AWS_REGION', 'us-east-2'))

# ============================================================================
# STRANDS FRAMEWORK CONCEPT: @tool decorator
# ============================================================================
# These tools give the AI agent the ability to generate reports and save them.
# The AI can create summaries, format them nicely, and upload them to S3.
# By breaking this into separate tools, the AI can handle each step
# intelligently and adapt to different situations.
# ============================================================================

@tool
def generate_claim_summary(claim_data: dict):
    """Generate a comprehensive claim processing summary"""
    logger.info("Generating claim summary")
    
    # STEP 1: Get current timestamp for the report
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
    
    # STEP 2: Extract all key claim information from the processed data
    # Pull out the important fields that should appear in the summary
    claim_number = claim_data.get('claim_number', 'N/A')
    policy_id = claim_data.get('policy_id', 'N/A')
    vehicle = f"{claim_data.get('vehicle_year', '')} {claim_data.get('vehicle_make', '')} {claim_data.get('vehicle_model', '')}".strip()
    damage_type = claim_data.get('damage_type', 'N/A')
    estimated_cost = claim_data.get('estimated_cost', 0)
    incident_date = claim_data.get('incident_date', 'N/A')
    
    # STEP 3: Extract fraud validation results
    # These fields were added by the fraud_validation_agent earlier in the workflow
    damage_consistent = claim_data.get('damage_consistent', True)
    validation_confidence = claim_data.get('validation_confidence', 0.0)
    validation_reasoning = claim_data.get('validation_reasoning', 'N/A')
    
    # STEP 4: Build the summary dictionary with all information
    # This creates a structured summary of the entire claim processing workflow
    summary = {
        'timestamp': timestamp,
        'claim_number': claim_number,
        'policy_id': policy_id,
        'vehicle': vehicle,
        'incident_date': incident_date,
        'damage_type': damage_type,
        'estimated_cost': estimated_cost,
        'damage_consistent': damage_consistent,
        'validation_confidence': validation_confidence,
        'validation_reasoning': validation_reasoning,
        # STEP 5: Generate recommendation based on validation results
        # If damage is consistent, approve; otherwise flag for review
        'recommendation': 'APPROVE CLAIM - Damage description matches image' if damage_consistent else 'REVIEW REQUIRED - Damage description inconsistent with image'
    }
    
    return summary

@tool
def upload_report_to_s3(report_content: str, claim_number: str, bucket_name: str, pdf_key: str = None):
    """Upload summary report to S3
    
    Args:
        report_content: The summary report text
        claim_number: Claim number from extracted data (may be None)
        bucket_name: S3 bucket name
        pdf_key: Optional S3 key of the PDF to extract claim folder from
    """
    logger.info(f"Uploading report to S3: {bucket_name}")
    
    try:
        # STEP 1: Extract claim folder from the original PDF path
        # Example: "submitted-claims/claim-1/file.pdf" -> "claim-1"
        # This maintains consistent folder organization
        claim_folder = None
        if pdf_key:
            import re
            match = re.search(r'(claim-\d+)', pdf_key)
            if match:
                claim_folder = match.group(1)
        
        # STEP 2: Fallback to claim_number if extraction failed
        if not claim_folder:
            claim_folder = f"claim-{claim_number}" if claim_number and claim_number != 'unknown' else 'claim-unknown'
        
        # STEP 3: Generate S3 key with organized folder structure
        # This creates a path like: processed-claims/claim-1/summary_20241122_143022.txt
        # The timestamp ensures each report has a unique name
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        s3_key = f"processed-claims/{claim_folder}/summary_{timestamp}.txt"
        
        # STEP 4: Upload the report to S3
        # This saves the summary report for future reference and auditing
        s3_client.put_object(
            Bucket=bucket_name,
            Key=s3_key,
            Body=report_content.encode('utf-8'),
            ContentType='text/plain'
        )
        
        logger.info(f"Report uploaded to: s3://{bucket_name}/{s3_key}")
        return f"Successfully uploaded to s3://{bucket_name}/{s3_key}"
        
    except Exception as e:
        logger.error(f"Error uploading to S3: {str(e)}")
        return f"Error uploading report: {str(e)}"

@tool
def format_summary_report(summary_data: dict):
    """Format summary data into a readable report"""
    logger.info("Formatting summary report")
    
    # STEP 1: Create a formatted text report with clear sections
    # This transforms the structured data into a readable document
    report = f"""
CLAIMS PROCESSING SUMMARY REPORT
================================
Generated: {summary_data['timestamp']}

CLAIM INFORMATION
-----------------
Claim Number: {summary_data['claim_number']}
Policy ID: {summary_data['policy_id']}
Vehicle: {summary_data['vehicle']}
Incident Date: {summary_data['incident_date']}
Damage Type: {summary_data['damage_type']}
Estimated Cost: ${summary_data['estimated_cost']:,.2f}

DAMAGE VALIDATION
-----------------
Description Matches Image: {'YES' if summary_data['damage_consistent'] else 'NO'}
Confidence Score: {summary_data['validation_confidence']:.1%}
Analysis: {summary_data['validation_reasoning']}

RECOMMENDATION
--------------
{summary_data['recommendation']}

---
Report generated by Claims Processing AI System with STRANDS framework
"""
    
    return report.strip()

# Configure the Bedrock model
model = BedrockModel(
    model_id="anthropic.claude-3-haiku-20240307-v1:0",
    additional_request_fields={
        "temperature": 0.1,
        "max_tokens": 1000,
    }
)

# Create the agent
agent = Agent(
    model=model,
    tools=[generate_claim_summary, format_summary_report, upload_report_to_s3],
    system_prompt="""You are a summary report generation agent for insurance claims processing.

Your job is to:
1. Generate comprehensive summaries of processed claims using generate_claim_summary
2. Format them into readable reports using format_summary_report
3. Upload the reports to S3 using upload_report_to_s3 with the bucket_name provided in the prompt

Always include all key claim information, fraud analysis results, and clear recommendations."""
)

@app.entrypoint
def bedrock_agent_runtime(payload):
    """Main entrypoint for summary report generation"""
    logger.info(f"Summary report payload: {payload}")
    
    try:
        entities = payload.get('entities', {})
        bucket = payload.get('bucket')
        
        if not bucket:
            logger.error("Bucket name not provided in payload")
            return json.dumps({'status': 'error', 'message': 'Bucket name required'})
        
        # Extract entities from nested structure if needed
        if isinstance(entities, dict) and 'entities' in entities:
            entities = entities['entities']
        
        claim_number = entities.get('claim_number', 'unknown')
        
        # Create prompt for summary generation
        prompt = f"""Please generate a comprehensive summary report for the processed claim:

CLAIM DATA: {json.dumps(entities)}
S3_BUCKET: {bucket}

Use the following steps:
1. Use generate_claim_summary to create summary data
2. Use format_summary_report to format it into a readable report
3. Use upload_report_to_s3 with bucket_name="{bucket}" to save the report

IMPORTANT: Use bucket_name="{bucket}" when calling upload_report_to_s3.

Return the final status and S3 location."""
        
        logger.info(f"Sending prompt to agent: {prompt[:200]}...")
        
        # Process through agent
        logger.info("Executing summary report agent...")
        response = agent(prompt)
        logger.info(f"Agent response received: {type(response)}")
        
        # Extract response text
        if response and hasattr(response, 'message'):
            content = response.message.get('content', [])
            logger.info(f"Response content: {content}")
            if content and len(content) > 0:
                response_text = content[0].get('text', '')
                logger.info(f"Summary report response: {response_text}")
                
                return json.dumps({
                    'status': 'success',
                    'message': 'Summary report generated and uploaded to S3',
                    'claim_number': claim_number
                })
            else:
                logger.warning("No content found in agent response")
        else:
            logger.warning(f"Invalid response format: {response}")
        
        return json.dumps({'status': 'error', 'message': 'No response from agent'})
        
    except Exception as e:
        logger.error(f"Error in summary report generation: {str(e)}")
        return json.dumps({'status': 'error', 'message': f'Failed to generate summary report: {str(e)}'})

if __name__ == "__main__":
    logger.info("Starting Summary Report Agent with STRANDS framework")
    app.run()
