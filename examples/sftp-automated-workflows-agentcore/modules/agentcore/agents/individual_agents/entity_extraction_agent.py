"""
Entity Extraction Agent using STRANDS framework
Extracts entities from claim documents using Claude 3.5 Sonnet
"""

import os
import json
import logging
import boto3
from PyPDF2 import PdfReader
from io import BytesIO
from strands import Agent, tool
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands.models import BedrockModel

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('entity-extraction-agent')

# Initialize the BedrockAgentCoreApp
app = BedrockAgentCoreApp()

# Initialize AWS clients
s3_client = boto3.client('s3', region_name=os.environ.get('AWS_REGION', 'us-east-2'))

# ============================================================================
# STRANDS FRAMEWORK CONCEPT: @tool decorator
# ============================================================================
# The @tool decorator gives the AI agent specific capabilities. In this agent,
# we define a tool that can read PDF files from S3. When the AI needs to
# extract text from a PDF, it will automatically call this tool with the
# appropriate bucket and key parameters.
# ============================================================================

@tool
def get_pdf_text(bucket: str, pdf_key: str):
    """Extract text content from PDF document in S3"""
    logger.info(f"Extracting text from PDF: s3://{bucket}/{pdf_key}")
    
    try:
        # STEP 1: Download the PDF file from S3
        # This retrieves the claim document that needs to be processed
        response = s3_client.get_object(Bucket=bucket, Key=pdf_key)
        pdf_content = response['Body'].read()
        
        # STEP 2: Parse the PDF and extract all text content
        # PyPDF2 reads the PDF structure and pulls out readable text from each page
        reader = PdfReader(BytesIO(pdf_content))
        text = ""
        for page in reader.pages:
            text += page.extract_text() + "\n"
        
        # STEP 3: Return the extracted text for the AI to analyze
        # The AI will read this text and extract structured claim information
        logger.info(f"Extracted {len(text)} characters from PDF")
        return text
        
    except Exception as e:
        logger.error(f"Error extracting PDF text: {str(e)}")
        return f"Error extracting PDF: {str(e)}"

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
    tools=[get_pdf_text],
    system_prompt="""You are an expert entity extraction agent for car damage insurance claims. 

Extract the following information from claim documents and return ONLY valid JSON with these exact fields:

{
    "policy_id": "string",
    "claim_number": "string", 
    "damage_type": "string",
    "estimated_cost": number,
    "vehicle_make": "string",
    "vehicle_model": "string",
    "vehicle_year": number,
    "incident_date": "string",
    "severity": "string",
    "description": "string"
}

If any field is not found, use null for that field. Return only the JSON object, no other text."""
)

@app.entrypoint
def bedrock_agent_runtime(payload):
    """Main entrypoint for entity extraction"""
    logger.info(f"Entity extraction payload: {payload}")
    
    try:
        bucket = payload.get('bucket')
        pdf_key = payload.get('pdf_key')
        
        if not bucket or not pdf_key:
            return json.dumps({"status": "error", "message": "Missing bucket or pdf_key"})
        
        # Create prompt for entity extraction
        prompt = f"""Please extract entities from the car damage claim PDF located at s3://{bucket}/{pdf_key}.

First, use the get_pdf_text tool to extract the text content, then analyze it and return the extracted entities in the specified JSON format."""
        
        logger.info(f"Sending prompt to agent: {prompt[:200]}...")
        
        # Process through agent
        logger.info("Executing entity extraction agent...")
        response = agent(prompt)
        logger.info(f"Agent response received: {type(response)}")
        
        # Extract response text
        if response and hasattr(response, 'message'):
            content = response.message.get('content', [])
            logger.info(f"Response content: {content}")
            if content and len(content) > 0:
                response_text = content[0].get('text', '{}')
                logger.info(f"Entity extraction response: {response_text}")
            else:
                logger.warning("No content found in agent response")
        else:
            logger.warning(f"Invalid response format: {response}")
            return json.dumps({"status": "error", "message": "No response from agent"})
                
        # Try to parse as JSON to validate
        try:
            entities = json.loads(response_text)
            return json.dumps({"status": "success", "entities": entities})
        except json.JSONDecodeError:
            # Try to extract JSON from response
                    import re
                    json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
                    if json_match:
                        entities = json.loads(json_match.group())
                        return json.dumps({"status": "success", "entities": entities})
                    else:
                        return json.dumps({"status": "error", "message": "Could not parse JSON from response"})
        
        return json.dumps({"status": "error", "message": "No response from agent"})
        
    except Exception as e:
        logger.error(f"Error in entity extraction: {str(e)}")
        return json.dumps({"status": "error", "message": str(e)})

if __name__ == "__main__":
    logger.info("Starting Entity Extraction Agent with STRANDS framework")
    app.run()
