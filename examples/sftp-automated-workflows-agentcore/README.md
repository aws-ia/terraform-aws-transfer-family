# SFTP Automated Workflows with AI Claims Processing

This example demonstrates a complete end-to-end solution for secure file transfer, automated malware protection, and AI-powered document processing using AWS Transfer Family, Amazon GuardDuty, and Amazon Bedrock AgentCore.

## Solution Overview

This solution showcases how organizations can automate the processing of sensitive documents submitted by external partners while maintaining security, compliance, and operational efficiency. The example uses an insurance claims processing scenario where auto repair shops submit damage claims via SFTP, which are then automatically scanned for malware, processed by AI agents for data extraction and fraud detection, and made available to internal staff through a secure web interface.

**Built with Terraform and AWS Transfer Family modules**, this solution provides production-ready infrastructure-as-code that can be deployed incrementally across 5 stages. The modular Terraform architecture uses the official AWS Transfer Family modules to provision secure file transfer infrastructure, making it easy to customize and extend for your specific use case.

**Key capabilities demonstrated**:
- Secure SFTP file transfer with custom authentication
- Automated malware scanning and file routing
- AI-powered document processing with multi-agent workflows
- Fraud detection using computer vision
- Role-based access control for internal users
- Automated deployment and testing scripts

**Technologies used**:
- **Terraform** for infrastructure-as-code deployment
- **AWS Transfer Family modules** (SFTP server, web app, custom IDP)
- Amazon GuardDuty Malware Protection
- Amazon Bedrock AgentCore with Claude models
- AWS Lambda for event-driven processing
- Amazon Cognito for external user authentication
- IAM Identity Center for internal user access
- S3 Access Grants for fine-grained permissions
- Amazon DynamoDB for claims storage

## Project Structure

```
.
├── README.md                        # This file
├── code-talk/                       # Automated deployment and test scripts
│   ├── stage0-deploy.sh            # Deploy identity foundation
│   ├── stage0-verify.sh            # Verify environment setup
│   ├── stage1-deploy.sh            # Deploy Transfer server
│   ├── stage1-test.sh              # Test SFTP upload
│   ├── stage2-deploy.sh            # Deploy malware protection
│   ├── stage2-test.sh              # Test malware scanning
│   ├── stage3-deploy.sh            # Deploy AI processing
│   ├── stage3-test.sh              # Test claims processing
│   ├── stage4-deploy.sh            # Deploy web application
│   ├── zip-claims.sh               # Utility to zip claim files
│   ├── cleanup.sh                  # Cleanup all resources
│   └── DEMO-SETUP.md               # Detailed setup guide
├── data/                            # Sample claim files
│   ├── claim-1/                    # Fraudulent claim (mismatched damage)
│   └── claim-2/                    # Legitimate claim
├── stage0-foundation.tf             # Identity Center, S3 Access Grants, Cognito
├── stage0-agentcore-ecr.tf          # ECR repositories and Docker builds
├── stage1-transfer-server.tf        # Transfer Server + Custom IDP
├── stage2-malware-protection.tf     # GuardDuty malware scanning
├── stage3-agentcore.tf              # AI claims processing
├── stage4-webapp.tf                 # Web application
├── stage0.tfvars                    # Stage 0 configuration
├── stage1.tfvars                    # Stage 1 configuration
├── stage2.tfvars                    # Stage 2 configuration
├── stage3.tfvars                    # Stage 3 configuration
├── stage4.tfvars                    # Stage 4 configuration
└── modules/                         # Reusable Terraform modules
    ├── transfer-webapp/            # Web app module
    ├── agentcore/                  # AI agents module
    └── ...
```

## Architecture Overview

The solution consists of 5 incremental stages that build upon each other:

### Stage 0: Identity Foundation + AgentCore ECR
**"Setting up identity and access infrastructure + Docker images"**
- IAM Identity Center with users and groups
- S3 Access Grants instance
- Cognito user pool for external authentication
- ECR repositories and Docker images for AgentCore agents (~2 min build time)

### Stage 1: Transfer Server with External Users
**"Secure file transfer with custom authentication"**
- Transfer Family SFTP server
- Custom Identity Provider (Lambda-based)
- S3 bucket for file storage
- External user (anycompany-repairs) authentication via Cognito

### Stage 2: Malware Protection
**"Automated malware scanning on upload"**
- GuardDuty Malware Protection
- Automatic scanning of uploaded files
- Clean and quarantine buckets
- File routing based on scan results

### Stage 3: AI Claims Processing
**"Intelligent claims processing with Bedrock"**
- AgentCore with Amazon Bedrock (agent deployment only)
- Automated claims data extraction
- Fraud detection with image analysis
- DynamoDB storage
- Uses pre-built Docker images from Stage 0

### Stage 4: Web Access for Internal Users
**"Complete solution with web-based file access"**
- Transfer Family Web App
- S3 Access Grants for fine-grained permissions
- Internal users (claims-reviewer, claims-administrator)
- Role-based access to processed claims

### How It All Works Together

**Automated File Processing Pipeline**:
1. **Upload**: External user uploads claim ZIP file via SFTP
2. **Extract**: Lambda extracts ZIP and organizes files in S3
3. **Scan**: GuardDuty scans for malware
4. **Route**: Clean files moved to processing bucket
5. **Process**: AI agents extract data, validate damage, detect fraud
6. **Store**: Results saved to DynamoDB
7. **Access**: Internal users review via web app

**Idempotency**: Uses EventBridge event IDs to prevent duplicate processing while allowing re-uploads for demo purposes.

## Quick Start

### Prerequisites

1. **Required Tools**:
   - AWS CLI configured with appropriate credentials
   - Terraform >= 1.0
   - jq (for JSON parsing)
   - SFTP client
   - zip utility

2. **AWS Account Requirements**:
   - Administrator access
   - No existing IAM Identity Center instance (or adjust configuration)
   - Bedrock model access enabled (Claude 3 Haiku and Claude 3.5 Sonnet)

### Automated Deployment and Testing

All deployment and testing scripts are located in the `code-talk/` directory. These scripts automate the entire process with built-in validation and helpful output.

#### Step 1: Deploy and Verify Stage 0 (Identity Foundation)

```bash
cd code-talk

# Deploy identity infrastructure and ECR repositories
./stage0-deploy.sh

# Verify environment setup
./stage0-verify.sh
```

**What this does**:
- Deploys IAM Identity Center, Cognito, S3 Access Grants
- Creates ECR repositories and builds Docker images for AI agents
- Verifies prerequisites and Bedrock model access

**Manual steps** (if verification fails):
- Enable Bedrock models in AWS Console (see DEMO-SETUP.md)
- Disable MFA in Identity Center for demo users
- Reset passwords for internal users

#### Step 2: Deploy and Test Stage 1 (Transfer Server)

```bash
# Deploy Transfer Family server
./stage1-deploy.sh

# Test SFTP upload
./stage1-test.sh
```

**What this does**:
- Deploys Transfer Family SFTP server with custom authentication
- Tests file upload via SFTP
- Automatically zips claim files and uploads them
- Cleans up test files after verification

#### Step 3: Deploy and Test Stage 2 (Malware Protection)

```bash
# Deploy GuardDuty malware scanning
./stage2-deploy.sh

# Test malware detection and file routing
./stage2-test.sh
```

**What this does**:
- Deploys GuardDuty Malware Protection with automatic file routing
- Tests with clean claim file and EICAR malware test file
- Monitors scan status tags in real-time
- Shows files routed to clean and quarantine buckets
- Cleans up test files

#### Step 4: Deploy and Test Stage 3 (AI Claims Processing)

```bash
# Deploy Bedrock AgentCore workflow
./stage3-deploy.sh

# Test AI claims processing
./stage3-test.sh
```

**What this does**:
- Deploys AgentCore workflow with 5 specialized agents
- Tests with claim-1 and claim-2 submissions
- Monitors agent logs in real-time (color-coded by agent type)
- Shows processed claims in DynamoDB
- Preserves files for Stage 4 web app access
- Press Ctrl+C to skip monitoring early

#### Step 5: Deploy Stage 4 (Web Application)

```bash
# Deploy web application for internal users
./stage4-deploy.sh
```

**What this does**:
- Deploys Transfer Family Web App
- Configures S3 Access Grants for role-based access
- Provides web app URL for browser access

**Access the web app**:
1. Open the web app URL from the deployment output
2. Sign in with Identity Center credentials:
   - `claims-reviewer` (read-only access to submitted and processed claims)
   - `claims-administrator` (full read/write access)

### Cleanup

When you're done with the demo, clean up all resources:

```bash
cd code-talk

# Option 1: Full cleanup (removes everything)
./cleanup.sh

# Option 2: Reset to Stage 0 (keeps identity foundation)
./cleanup.sh --reset-to-stage0
```

**What this does**:
- Empties all S3 buckets (including versioned objects and delete markers)
- Deletes CloudWatch log groups for agents
- Destroys all infrastructure via Terraform
- Option to preserve Stage 0 for faster re-deployment

## Testing the Solution

### Test Files Included

- **claim-1**: Fraudulent claim with mismatched damage description
  - PDF describes minor rear bumper damage
  - Photo shows severe front-end damage
  - AI detects inconsistency with 99% confidence

- **claim-2**: Legitimate claim with matching description
  - PDF and photo align correctly
  - AI validates as consistent

### Monitoring Agent Activity

The `stage3-test.sh` script provides real-time monitoring of agent logs with color-coded output:

- 🟣 **[WORKFLOW]** - Orchestration agent
- 🔵 **[ENTITY]** - Data extraction agent
- 🔴 **[FRAUD]** - Damage validation agent
- 🟡 **[DATABASE]** - Database insertion agent
- 🟢 **[SUMMARY]** - Summary generation agent

Press **Ctrl+C** during monitoring to skip to the next step.

## Details about the AI Agent Architecture

The solution uses 5 specialized AI agents built with the STRANDS framework and Amazon Bedrock. Each agent has a specific role and uses Claude models for intelligent processing.

### 1. Workflow Orchestrator Agent

**Purpose**: Coordinates the entire claims processing pipeline

**Model**: Claude 3 Haiku (fast, cost-effective for orchestration)

**System Prompt**:
```
You are a claims processing workflow orchestrator using the STRANDS framework.

Your job is to coordinate the complete claims processing pipeline:
1. Extract entities from claim PDF using invoke_entity_extraction(bucket, pdf_key)
2. Validate damage consistency using invoke_fraud_validation(entities, bucket, image_key)
3. Insert enriched data into database using invoke_database_insertion(enriched_entities, bucket, pdf_key, image_key)
4. Generate summary report using invoke_summary_generation(enriched_entities, bucket)

Execute these steps in order and return a comprehensive result showing the status of each step.
```

**Tools Available**:
- `invoke_entity_extraction()` - Calls the entity extraction agent
- `invoke_fraud_validation()` - Calls the fraud validation agent
- `invoke_database_insertion()` - Calls the database agent
- `invoke_summary_generation()` - Calls the summary agent

**How It Works**: The workflow agent receives the S3 bucket and file locations, then intelligently calls each specialized agent in sequence, passing results from one agent to the next.

### 2. Entity Extraction Agent

**Purpose**: Extracts structured claim data from PDF documents

**Model**: Claude 3 Haiku (efficient for text extraction)

**System Prompt**:
```
You are an expert entity extraction agent for car damage insurance claims.

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

If any field is not found, use null for that field. Return only the JSON object, no other text.
```

**Tools Available**:
- `get_pdf_text(bucket, pdf_key)` - Downloads and extracts text from PDF using PyPDF2

**How It Works**: Downloads the claim PDF from S3, extracts all text content, then uses Claude to identify and structure the key claim information into a standardized JSON format.

### 3. Fraud Validation Agent

**Purpose**: Compares PDF damage description with actual damage photos to detect fraud

**Model**: Claude 3.5 Sonnet (advanced vision capabilities for image analysis)

**System Prompt**:
```
You are a damage validation specialist. Your job is to compare the damage description from a claim report with the actual damage shown in a photo.

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
- If PDF says "severe front-end damage" and image shows crushed front, that's CONSISTENT
```

**Tools Available**:
- `get_damage_image(bucket, image_key)` - Downloads image from S3 and converts to base64 for vision analysis

**How It Works**: Receives the extracted claim entities and damage description, downloads the damage photo, then uses Claude's vision capabilities to compare the written description with what's actually shown in the image. Returns a fraud assessment with confidence score and reasoning.

### 4. Database Insertion Agent

**Purpose**: Stores processed claim data in DynamoDB

**Model**: Claude 3 Haiku (simple data formatting task)

**System Prompt**:
```
You are a database insertion agent for insurance claims processing.

Your job is to:
1. Take processed claim entities with damage validation results
2. Format them properly for database insertion
3. Insert the data into DynamoDB
4. Return confirmation of successful insertion

Always ensure the claim_id field is present as it's the primary key for the DynamoDB table.
```

**Tools Available**:
- `insert_claim_data(claim_data, table_name)` - Formats and inserts data into DynamoDB
- `format_claim_metadata(bucket, pdf_key, image_key)` - Creates metadata about source files

**How It Works**: Takes the enriched claim data (including fraud validation results), formats it for DynamoDB's data structure (converting types to S, N, BOOL), and inserts it into the claims table for permanent storage.

### 5. Summary Generation Agent

**Purpose**: Creates human-readable summary reports

**Model**: Claude 3 Haiku (efficient for text generation)

**System Prompt**:
```
You are a summary report generation agent for insurance claims processing.

Your job is to:
1. Generate comprehensive summaries of processed claims using generate_claim_summary
2. Format them into readable reports using format_summary_report
3. Upload the reports to S3 using upload_report_to_s3 with the bucket_name provided in the prompt

Always include all key claim information, fraud analysis results, and clear recommendations.
```

**Tools Available**:
- `generate_claim_summary(claim_data)` - Creates structured summary with all key information
- `format_summary_report(summary_data)` - Formats into readable text report
- `upload_report_to_s3(report_content, claim_number, bucket_name, pdf_key)` - Saves report to S3

**How It Works**: Takes the fully processed claim data, generates a comprehensive summary including fraud analysis results, formats it into a readable report, and uploads it to S3 in the `processed-claims/` folder for review by claims adjusters.

### STRANDS Framework

All agents are built using the **STRANDS framework**, which provides:

- **@tool decorator**: Marks functions as tools that AI agents can use
- **Agent class**: Wraps Claude models with tool-calling capabilities
- **BedrockAgentCoreApp**: Provides the runtime environment for agent deployment

The framework allows agents to:
1. Read their tool descriptions from docstrings
2. Decide when to call each tool based on the task
3. Pass appropriate parameters to tools
4. Chain multiple tool calls together
5. Return structured results

This architecture demonstrates how to build production-ready AI workflows with specialized agents, each focused on a specific task, working together to process complex business workflows.

## Important Notes

1. **Stage Dependencies**: Each stage builds on the previous one. Deploy in order (0 → 1 → 2 → 3 → 4).

2. **Identity Center**: Only one Identity Center instance per AWS account. If you already have one, you may need to adjust the configuration.

3. **Bedrock Model Access**: Ensure Claude 3 Haiku and Claude 3.5 Sonnet are enabled in your AWS account before deploying Stage 3.

4. **Costs**: Be aware of AWS service costs for Transfer Family, GuardDuty Malware Protection, Bedrock, AgentCore, CloudWatch Logs, Lambda, S3, and DynamoDB.

5. **Cleanup**: Always clean up any infrastructure you create to avoid unnecessary charges. The `cleanup.sh` script automates the cleanup of S3 buckets, CloudWatch log groups, and performs the Terraform destroy operation.

6. **ZIP File Format**: Claims must be uploaded as ZIP files containing:
   - One PDF file (claim report)
   - One image file (PNG/JPG of damage)
   - Named as `claim-N.zip` (e.g., `claim-1.zip`)
   - The `stage3-test.sh` script automatically zips claim-1 and claim-2 from the data folder for you

## Troubleshooting

### Common Issues

**Issue**: `./stage0-deploy.sh: command not found`
- **Solution**: Ensure you're in the correct directory
  - From workspace root: `cd examples/sftp-automated-workflows-agentcore/code-talk`
  - Or if already in example: `cd code-talk`
- **Solution**: Ensure script is executable: `chmod +x stage0-deploy.sh`

**Issue**: Terraform state conflicts
- **Solution**: Ensure you're in the `examples/sftp-automated-workflows-agentcore` directory (not `code-talk`) when running Terraform commands
- **Solution**: Verify you're using the correct tfvars file for the stage

**Issue**: Agent logs not appearing
- **Solution**: Wait 5-10 seconds for agents to start processing
- **Solution**: Verify Stage 3 was deployed successfully

**Issue**: AI agent errors in logs (model access denied, invocation errors)
- **Solution**: Bedrock models not enabled - see `code-talk/DEMO-SETUP.md` Step 3A to enable Claude 3 Haiku and Claude 3.5 Sonnet
- **Solution**: Run `./stage0-verify.sh` from the `code-talk` directory to check model access

**Issue**: S3 bucket deletion fails when trying to run terraform destroy
- **Solution**: Run `./cleanup.sh` from the `code-talk` directory - it handles versioned objects and delete markers automatically
- **Solution**: Alternatively run `./cleanup.sh --reset-to-stage0` to preserve Stage 0 infrastructure

**Issue**: Identity Center or MFA-related errors during web app login
- **Solution**: Complete manual Identity Center configuration - see `code-talk/DEMO-SETUP.md` Step 3B

For comprehensive setup instructions and additional troubleshooting, see `code-talk/DEMO-SETUP.md`.

## Manual Deployment (Advanced)

If you prefer manual Terraform commands instead of the automated scripts:

```bash
# Stage 0
terraform init
terraform apply -var-file=stage0.tfvars

# Stage 1
terraform apply -var-file=stage1.tfvars

# Stage 2
terraform apply -var-file=stage2.tfvars

# Stage 3
terraform apply -var-file=stage3.tfvars

# Stage 4
terraform apply -var-file=stage4.tfvars

# Cleanup
terraform destroy
```

**Note**: Manual deployment requires manual verification, testing, and cleanup steps.

## Outputs

View deployment outputs at any time:

```bash
terraform output
```

Key outputs include:
- Transfer server endpoint
- Cognito username and password (in Secrets Manager)
- Web app endpoint
- S3 bucket names
- AgentCore workflow agent ID
- DynamoDB table name

## License

This example is provided under the MIT-0 License. See LICENSE file for details.
