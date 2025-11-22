# Claims Processing System

A complete AI-powered claims processing system using Amazon Bedrock AgentCore with multi-agent orchestration for document processing, fraud detection, and automated reporting.

## Architecture

The system consists of 5 specialized agents:

- **Workflow Agent**: Orchestrates the entire claims processing pipeline
- **Entity Extraction Agent**: Extracts structured data from PDF documents
- **Fraud Validation Agent**: Analyzes claims for potential fraud using image and text analysis
- **Database Insertion Agent**: Stores processed claims in DynamoDB with fraud flags
- **Summary Generation Agent**: Creates comprehensive reports and uploads to S3

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed and running
- Terraform >= 1.0.7

## Quick Deploy

1. **Initialize and deploy:**
   ```bash
   ./run-terraform.sh init
   ./run-terraform.sh plan
   ./run-terraform.sh apply
   ```

2. **Get deployment outputs:**
   ```bash
   ./run-terraform.sh output
   ```

## Testing

After deployment, test the system:

1. Go to AWS Console > Bedrock AgentCore > Agent Runtime
2. Find the `workflow_agent` and click "Test endpoint"
3. Use this test payload:
   ```json
   {
     "bucket": "car-damage-claims-bucket",
     "pdf_key": "claim-2/car_damage_claim_report.pdf",
     "image_key": "claim-2/claim-2.png"
   }
   ```

## What Gets Created

- 5 ECR repositories for agent Docker images
- 5 Bedrock AgentCore runtimes with DEFAULT endpoints
- Automatic Docker image building and pushing
- All necessary IAM roles and permissions

## Cleanup

To destroy all resources:
```bash
./run-terraform.sh destroy
```

## Architecture Diagram

```
S3 Upload → Lambda → Workflow Agent → Entity Extraction Agent
                                   ↓
Summary Agent ← Database Agent ← Fraud Validation Agent
     ↓
   S3 Report
```

## Fraud Detection

The system automatically flags fraudulent claims based on:
- Cost vs damage inconsistencies
- Timeline anomalies
- Image analysis discrepancies
- Historical patterns

Results are stored in DynamoDB with:
- `fraud`: Boolean flag
- `confidence_score`: 0-100 confidence level
- `reason`: Detailed explanation
