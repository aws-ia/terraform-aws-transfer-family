"""
Claims Workflow Orchestrator using STRANDS framework
Orchestrates the complete claims processing pipeline
"""

import os
import json
import logging
import boto3
from strands import Agent, tool
from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands.models import BedrockModel

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('claims-workflow-orchestrator')

# Initialize the BedrockAgentCoreApp
app = BedrockAgentCoreApp()

# Initialize AWS clients
bedrock_agentcore_client = boto3.client('bedrock-agentcore', region_name=os.environ.get('AWS_REGION', 'us-east-2'))

@tool
def invoke_entity_extraction(bucket: str, pdf_key: str):
    """Invoke entity extraction agent to extract claim data from PDF"""
    logger.info(f"Invoking entity extraction for s3://{bucket}/{pdf_key}")
    
    try:
        entity_agent_arn = os.environ.get('ENTITY_AGENT_ARN')
        if not entity_agent_arn:
            return "Error: ENTITY_AGENT_ARN not configured"
        
        payload = {"bucket": bucket, "pdf_key": pdf_key}
        session_id = f"entity_session_{abs(hash(str(payload))):026d}"
        
        response = bedrock_agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=entity_agent_arn,
            runtimeSessionId=session_id,
            payload=json.dumps(payload),
            qualifier="DEFAULT"
        )
        
        response_body = response['response'].read()
        result = json.loads(response_body)
        logger.info(f"Entity extraction completed: {result}")
        return json.dumps(result)
        
    except Exception as e:
        logger.error(f"Entity extraction error: {str(e)}")
        return f"Error in entity extraction: {str(e)}"

@tool
def invoke_fraud_validation(entities: str, bucket: str, image_key: str):
    """Invoke damage validation agent to compare PDF description with actual damage image"""
    logger.info("Invoking damage validation")
    
    try:
        fraud_agent_arn = os.environ.get('FRAUD_AGENT_ARN')
        if not fraud_agent_arn:
            return json.dumps({"error": "FRAUD_AGENT_ARN not configured"})
        
        entities_data = json.loads(entities) if isinstance(entities, str) else entities
        
        payload = {"entities": entities_data, "bucket": bucket, "image_key": image_key}
        session_id = f"validation_session_{abs(hash(str(payload))):026d}"
        
        response = bedrock_agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=fraud_agent_arn,
            runtimeSessionId=session_id,
            payload=json.dumps(payload),
            qualifier="DEFAULT"
        )
        
        response_body = response['response'].read()
        validation_result = json.loads(response_body)
        logger.info(f"Damage validation completed: {validation_result}")
        
        # Handle double JSON encoding if validation agent returns string
        if isinstance(validation_result, str):
            validation_result = json.loads(validation_result)
        
        # Enrich entities with validation data
        entities_data['damage_consistent'] = validation_result.get('consistent', True)
        entities_data['validation_confidence'] = validation_result.get('confidence', 0.0)
        entities_data['validation_reasoning'] = validation_result.get('reasoning', 'N/A')
        
        logger.info(f"Enriched entities: {entities_data}")
        return json.dumps(entities_data)
        
    except Exception as e:
        logger.error(f"Damage validation error: {str(e)}")
        return json.dumps({"error": str(e)})

@tool
def invoke_database_insertion(entities: str, bucket: str, pdf_key: str, image_key: str):
    """Invoke database insertion agent to store processed claim data"""
    logger.info("Invoking database insertion")
    
    try:
        database_agent_arn = os.environ.get('DATABASE_AGENT_ARN')
        if not database_agent_arn:
            return "Error: DATABASE_AGENT_ARN not configured"
        
        # Parse entities if it's a string
        if isinstance(entities, str):
            entities_data = json.loads(entities)
        else:
            entities_data = entities
        
        payload = {
            "entities": entities_data,
            "bucket": bucket,
            "pdf_key": pdf_key,
            "image_key": image_key
        }
        session_id = f"db_session_{abs(hash(str(payload))):026d}"
        
        response = bedrock_agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=database_agent_arn,
            runtimeSessionId=session_id,
            payload=json.dumps(payload),
            qualifier="DEFAULT"
        )
        
        response_body = response['response'].read()
        result = json.loads(response_body)
        logger.info(f"Database insertion completed: {result}")
        return json.dumps(result)
        
    except Exception as e:
        logger.error(f"Database insertion error: {str(e)}")
        return f"Error in database insertion: {str(e)}"

@tool
def invoke_summary_generation(entities: str, bucket: str):
    """Invoke summary generation agent to create final report"""
    logger.info(f"Invoking summary generation for bucket: {bucket}")
    
    try:
        summary_agent_arn = os.environ.get('SUMMARY_AGENT_ARN')
        if not summary_agent_arn:
            return "Error: SUMMARY_AGENT_ARN not configured"
        
        # Parse entities if it's a string
        if isinstance(entities, str):
            entities_data = json.loads(entities)
        else:
            entities_data = entities
        
        payload = {"entities": entities_data, "bucket": bucket}
        session_id = f"summary_session_{abs(hash(str(payload))):026d}"
        
        response = bedrock_agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=summary_agent_arn,
            runtimeSessionId=session_id,
            payload=json.dumps(payload),
            qualifier="DEFAULT"
        )
        
        response_body = response['response'].read()
        result = json.loads(response_body)
        logger.info(f"Summary generation completed: {result}")
        return json.dumps(result)
        
    except Exception as e:
        logger.error(f"Summary generation error: {str(e)}")
        return f"Error in summary generation: {str(e)}"

# Configure the Bedrock model
model = BedrockModel(
    model_id="anthropic.claude-3-haiku-20240307-v1:0",
    additional_request_fields={
        "temperature": 0.1,
        "max_tokens": 1500,
    }
)

# Create the agent
agent = Agent(
    model=model,
    tools=[invoke_entity_extraction, invoke_fraud_validation, invoke_database_insertion, invoke_summary_generation],
    system_prompt="""You are a claims processing workflow orchestrator using the STRANDS framework.

Your job is to coordinate the complete claims processing pipeline:

1. Extract entities from claim PDF using invoke_entity_extraction(bucket, pdf_key)
2. Validate damage consistency using invoke_fraud_validation(entities, bucket, image_key) 
   - This compares the PDF damage description with the actual damage image
   - Returns enriched entities with validation results (consistent/inconsistent)
3. Insert enriched data into database using invoke_database_insertion(enriched_entities, bucket, pdf_key, image_key)
4. Generate summary report using invoke_summary_generation(enriched_entities, bucket)

The invoke_fraud_validation tool adds validation fields to entities. Use its return value for subsequent steps.

Execute these steps in order and return a comprehensive result showing the status of each step."""
)

@app.entrypoint
def bedrock_agent_runtime(payload):
    """Main entrypoint for claims workflow orchestration"""
    logger.info(f"Claims workflow payload: {payload}")
    
    execution_log = []
    
    try:
        bucket = payload.get('bucket')
        pdf_key = payload.get('pdf_key')
        image_key = payload.get('image_key')
        
        if not bucket or not pdf_key:
            return json.dumps({"status": "error", "message": "Missing required parameters: bucket, pdf_key"})
        
        execution_log.append(f"Starting workflow: bucket={bucket}, pdf_key={pdf_key}, image_key={image_key}")
        logger.info(f"Processing claims with bucket={bucket}, pdf_key={pdf_key}, image_key={image_key}")
        
        # Create prompt for workflow orchestration
        prompt = f"""Please process the insurance claim with the following details:

BUCKET: {bucket}
PDF_KEY: {pdf_key}
IMAGE_KEY: {image_key}

Execute the complete claims processing workflow:
1. Extract entities from the PDF document
2. Validate for fraud using the damage image
3. Insert the processed data into the database
4. Generate a summary report

Return the results of each step."""
        
        execution_log.append("Invoking STRANDS agent for workflow orchestration")
        logger.info(f"Sending prompt to agent: {prompt[:200]}...")  # Log first 200 chars
        
        # Process through agent
        logger.info("Executing workflow orchestration agent...")
        response = agent(prompt)
        logger.info(f"Agent response received: {type(response)}")
        
        # Extract response text
        if response and hasattr(response, 'message'):
            content = response.message.get('content', [])
            logger.info(f"Response content: {content}")
            if content and len(content) > 0:
                response_text = content[0].get('text', '')
                execution_log.append(f"Agent response: {response_text}")
                logger.info(f"Workflow orchestration response: {response_text}")
            else:
                logger.warning("No content found in agent response")
        else:
            logger.warning(f"Invalid response format: {response}")
            return json.dumps({"status": "error", "message": "No response from agent"})
                
        return json.dumps({
            "status": "success",
            "message": "Claims processing workflow completed",
            "processed_files": {
                "bucket": bucket,
                "pdf_key": pdf_key,
                        "image_key": image_key
                    },
                    "execution_log": execution_log,
                    "agent_response": response_text
                })
        
        execution_log.append("No response from workflow orchestrator")
        return json.dumps({
            "status": "error", 
            "message": "No response from workflow orchestrator",
            "execution_log": execution_log
        })
        
    except Exception as e:
        execution_log.append(f"Error: {str(e)}")
        logger.error(f"Error in claims workflow: {str(e)}")
        return json.dumps({
            "status": "error", 
            "message": str(e),
            "execution_log": execution_log
        })

if __name__ == "__main__":
    logger.info("Starting Claims Workflow Orchestrator with STRANDS framework")
    app.run()
