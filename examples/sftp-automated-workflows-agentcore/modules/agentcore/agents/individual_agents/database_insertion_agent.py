"""
Database Insertion Agent using STRANDS framework
Inserts extracted and validated claim entities into DynamoDB
"""

import os
import json
import logging
import boto3
import time
from strands import Agent, tool
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands.models import BedrockModel

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('database-insertion-agent')

# Initialize the BedrockAgentCoreApp
app = BedrockAgentCoreApp()

# Initialize AWS clients
dynamodb = boto3.client('dynamodb', region_name=os.environ.get('AWS_REGION', 'us-east-2'))

@tool
def insert_claim_data(claim_data: dict, table_name: str = 'claims-table'):
    """Insert claim data into DynamoDB table"""
    logger.info(f"Inserting claim data into {table_name}")
    
    try:
        # Convert entities to DynamoDB format
        item = {}
        
        # Add claim_id as the hash key (required by DynamoDB table)
        claim_id = claim_data.get('claim_number', f"claim_{int(time.time())}")
        item['claim_id'] = {'S': claim_id}
        
        for key, value in claim_data.items():
            if isinstance(value, str):
                item[key] = {'S': value}
            elif isinstance(value, bool):  # Handle booleans BEFORE numbers
                item[key] = {'BOOL': value}
            elif isinstance(value, (int, float)):
                item[key] = {'N': str(value)}
            else:
                item[key] = {'S': str(value)}
        
        logger.info(f"Formatted DynamoDB item: {item}")
        
        # Insert into DynamoDB
        response = dynamodb.put_item(
            TableName=table_name,
            Item=item
        )
        
        logger.info(f"DynamoDB response: {response}")
        return f"Successfully inserted claim {claim_id} into {table_name}"
        
    except Exception as e:
        logger.error(f"Error inserting into DynamoDB: {str(e)}")
        return f"Error inserting data: {str(e)}"

@tool
def format_claim_metadata(bucket: str, pdf_key: str, image_key: str = None):
    """Format claim metadata for database insertion"""
    logger.info("Formatting claim metadata")
    
    metadata = {
        'source_bucket': bucket or 'unknown',
        'source_pdf': pdf_key or 'unknown'
    }
    
    if image_key:
        metadata['source_image'] = image_key
    
    return metadata

# Configure the Bedrock model
model = BedrockModel(
    model_id="anthropic.claude-3-haiku-20240307-v1:0",
    additional_request_fields={
        "temperature": 0.1,
        "max_tokens": 500,
    }
)

# Create the agent
agent = Agent(
    model=model,
    tools=[insert_claim_data, format_claim_metadata],
    system_prompt="""You are a database insertion agent for insurance claims processing.

Your job is to:
1. Take processed claim entities with damage validation results
2. Format them properly for database insertion
3. Insert the data into DynamoDB
4. Return confirmation of successful insertion

Always ensure the claim_id field is present as it's the primary key for the DynamoDB table."""
)

@app.entrypoint
def bedrock_agent_runtime(payload):
    """Main entrypoint for database insertion"""
    logger.info(f"Database insertion payload: {payload}")
    
    try:
        entities = payload.get('entities', {})
        bucket = payload.get('bucket')
        pdf_key = payload.get('pdf_key')
        image_key = payload.get('image_key')
        
        # Extract entities from nested structure if needed
        if isinstance(entities, dict) and 'entities' in entities:
            entities = entities['entities']
        
        logger.info(f"Processing entities: {entities}")
        
        # Create prompt for database insertion
        prompt = f"""Please insert the following claim data into the DynamoDB table:

CLAIM ENTITIES: {json.dumps(entities)}
BUCKET: {bucket}
PDF_KEY: {pdf_key}
IMAGE_KEY: {image_key}

First, use the format_claim_metadata tool to prepare metadata, then use the insert_claim_data tool to insert all the data into the claims-table."""
        
        logger.info(f"Sending prompt to agent: {prompt[:200]}...")
        
        # Process through agent
        logger.info("Executing database insertion agent...")
        response = agent(prompt)
        logger.info(f"Agent response received: {type(response)}")
        
        # Extract response text
        if response and hasattr(response, 'message'):
            content = response.message.get('content', [])
            logger.info(f"Response content: {content}")
            if content and len(content) > 0:
                response_text = content[0].get('text', '')
                logger.info(f"Database insertion response: {response_text}")
                
                return json.dumps({
                    "status": "success",
                    "message": "Successfully inserted into DynamoDB",
                    "claim_id": entities.get('claim_number', 'unknown'),
                    "table_name": "claims-table"
                })
            else:
                logger.warning("No content found in agent response")
        else:
            logger.warning(f"Invalid response format: {response}")
        
        return json.dumps({"status": "error", "message": "No response from agent"})
        
    except Exception as e:
        logger.error(f"Error in database insertion: {str(e)}")
        return json.dumps({"status": "error", "message": str(e)})

if __name__ == "__main__":
    logger.info("Starting Database Insertion Agent with STRANDS framework")
    app.run()
