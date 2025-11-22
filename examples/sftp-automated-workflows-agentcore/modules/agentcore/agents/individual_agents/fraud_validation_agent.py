"""
Damage Validation Agent using STRANDS framework
Compares PDF damage description with actual damage image to verify consistency
"""

import os
import json
import logging
import boto3
import base64
from strands import Agent, tool
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands.models import BedrockModel

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('damage-validation-agent')

# Initialize the BedrockAgentCoreApp
app = BedrockAgentCoreApp()

# Initialize AWS clients
s3_client = boto3.client('s3', region_name=os.environ.get('AWS_REGION', 'us-east-2'))

@tool
def get_damage_image(bucket: str, image_key: str) -> str:
    """Retrieve damage image from S3 bucket"""
    logger.info(f"Retrieving image from s3://{bucket}/{image_key}")
    
    try:
        response = s3_client.get_object(Bucket=bucket, Key=image_key)
        image_data = response['Body'].read()
        return base64.b64encode(image_data).decode('utf-8')
    except Exception as e:
        logger.error(f"Error retrieving image: {str(e)}")
        return f"Error: {str(e)}"

# Configure the Bedrock model with vision capabilities
model = BedrockModel(
    model_id="anthropic.claude-3-5-sonnet-20240620-v1:0",
    additional_request_fields={
        "temperature": 0.1,
        "max_tokens": 500,
    }
)

# Create the agent
agent = Agent(
    model=model,
    tools=[get_damage_image],
    system_prompt="""You are a damage validation specialist. Your job is to compare the damage description from a claim report with the actual damage shown in a photo.

Steps:
1. Review the damage description from the PDF (provided in the prompt)
2. Use get_damage_image to retrieve and examine the actual damage photo
3. Compare the description with what you see in the image
4. Determine if they are consistent or inconsistent

Return ONLY a JSON object with this exact format:
{
    "consistent": true/false,
    "confidence": 0.0-1.0,
    "reasoning": "Brief explanation of why the description matches or doesn't match the image"
}

Be specific about discrepancies. For example:
- If PDF says "minor scratches" but image shows totaled vehicle, that's INCONSISTENT
- If PDF says "severe front-end damage" and image shows crushed front, that's CONSISTENT"""
)

@app.entrypoint
def bedrock_agent_runtime(payload):
    """Main entrypoint for damage validation"""
    logger.info(f"Damage validation payload: {payload}")
    
    try:
        bucket = payload.get('bucket')
        image_key = payload.get('image_key') 
        entities = payload.get('entities', {})
        
        if not bucket or not image_key:
            return json.dumps({"status": "error", "message": "Missing bucket or image_key"})
        
        # Extract damage information from entities
        damage_type = entities.get('damage_type', 'unknown')
        severity = entities.get('severity', 'unknown')
        description = entities.get('description', 'unknown')
        claim_id = entities.get('claim_number', 'unknown')
        
        prompt = f"""Compare the claim damage description with the actual damage image.

CLAIM INFORMATION:
- Claim ID: {claim_id}
- Damage Type: {damage_type}
- Severity: {severity}
- Description: {description}

IMAGE LOCATION: s3://{bucket}/{image_key}

Please:
1. Retrieve the damage image using get_damage_image
2. Examine the actual damage shown in the photo
3. Compare it with the description above
4. Return your validation result in the specified JSON format"""
        
        logger.info(f"Validating damage for claim {claim_id}")
        response = agent(prompt)
        
        # Extract response text
        response_text = ""
        if response and hasattr(response, 'message'):
            content = response.message.get('content', [])
            if content and len(content) > 0:
                response_text = content[0].get('text', '')
                logger.info(f"Validation result: {response_text}")
        
        # Try to extract JSON from response
        import re
        json_match = re.search(r'\{[^}]*"consistent"[^}]*\}', response_text, re.DOTALL)
        if json_match:
            validation_data = json.loads(json_match.group())
            return json.dumps({
                "status": "success",
                "claim_id": claim_id,
                "consistent": validation_data.get("consistent", True),
                "confidence": validation_data.get("confidence", 0.0),
                "reasoning": validation_data.get("reasoning", "")
            })
        
        return json.dumps({
            "status": "success",
            "claim_id": claim_id,
            "response": response_text
        })
        
    except Exception as e:
        logger.error(f"Error in damage validation: {str(e)}")
        return json.dumps({"status": "error", "message": str(e)})

if __name__ == "__main__":
    logger.info("Starting Damage Validation Agent with STRANDS framework")
    app.run()
