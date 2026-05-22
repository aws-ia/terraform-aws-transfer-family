# Requirements Document

## Introduction

Update the code-talk demo scripts and demo/ scripts in `examples/sftp-automated-workflows-agentcore/` to align with the refactored nys-2026 architecture. The refactoring replaced 5 Docker/ECR agents with 4 Python zip/S3 agents plus a Lambda orchestrator, changed agent names, switched packaging from Docker/ECR to Python zip (uv pip install) uploaded to S3, updated the Bedrock model to Claude Sonnet 4.6, introduced an MCP gateway architecture, and removed the `agentcore_workflow_agent_runtime_id` Terraform output.

## Glossary

- **Demo_Scripts**: The shell scripts and markdown files in `demo/` and `code-talk/` directories used for deploying, verifying, testing, and monitoring the claims processing demo
- **Terraform_Outputs**: The values exported by `outputs.tf` that scripts consume at runtime to discover resource identifiers and connection details
- **Agent_Runtime**: A Bedrock AgentCore runtime instance running a Python zip package uploaded to S3
- **MCP_Gateway**: The Model Context Protocol gateway deployed in Stage 3 that provides tool access to 3 of the 4 agents
- **Orchestrator_Lambda**: The Lambda function (`claims-orchestrator`) that drives the 4 agents through the pipeline stages, triggered by S3 Object Created events on the clean bucket
- **Monitor_Script**: `demo/monitor_agents.sh` — a shell script that tails CloudWatch log groups for agent runtimes
- **Run_Demo_Script**: `demo/run_demo.sh` — a shell script that displays demo instructions and SFTP connection details
- **Stage0_Deploy_Script**: `code-talk/stage0-deploy.sh` — deploys Stage 0 infrastructure
- **Stage0_Verify_Script**: `code-talk/stage0-verify.sh` — verifies environment setup after Stage 0 deployment
- **Stage3_Deploy_Script**: `code-talk/stage3-deploy.sh` — deploys Stage 3 infrastructure
- **Stage3_Test_Script**: `code-talk/stage3-test.sh` — tests AI claims processing end-to-end
- **Demo_Setup_Doc**: `code-talk/DEMO-SETUP.md` — detailed setup guide for the demo
- **README_Doc**: `README.md` — top-level documentation for the example

## Requirements

### Requirement 1: Dynamic Connection Details in Run Demo Script

**User Story:** As a demo operator, I want `demo/run_demo.sh` to pull SFTP connection details dynamically from Terraform outputs at runtime, so that the script works across different deployments without hardcoded values.

#### Acceptance Criteria

1. WHEN the Run_Demo_Script is executed, THE Run_Demo_Script SHALL retrieve the Transfer server endpoint from Terraform output `transfer_server_endpoint`
2. WHEN the Run_Demo_Script is executed, THE Run_Demo_Script SHALL retrieve the Cognito username from Terraform output `cognito_username`
3. WHEN the Run_Demo_Script is executed, THE Run_Demo_Script SHALL retrieve the password from Secrets Manager using the ARN from Terraform output `cognito_password_secret_arn`
4. THE Run_Demo_Script SHALL display the dynamically retrieved SFTP connection command using the resolved server endpoint and username
5. THE Run_Demo_Script SHALL remove all hardcoded SFTP server addresses, usernames, and passwords
6. WHEN the Run_Demo_Script displays monitoring options, THE Run_Demo_Script SHALL reference the updated agent names: document-extraction, damage-assessment, fraud-detection, classification
7. THE Run_Demo_Script SHALL describe the updated pipeline steps: document extraction, damage assessment, fraud detection, classification, and summary generation

### Requirement 2: Dynamic Log Group Discovery in Monitor Agents Script

**User Story:** As a demo operator, I want `demo/monitor_agents.sh` to construct CloudWatch log group names dynamically from Terraform outputs, so that monitoring works regardless of the runtime-generated identifiers in log group paths.

#### Acceptance Criteria

1. WHEN the Monitor_Script is executed, THE Monitor_Script SHALL retrieve agent runtime ARNs from Terraform outputs: `agentcore_document_extraction_agent_arn`, `agentcore_damage_assessment_agent_arn`, `agentcore_fraud_detection_agent_arn`, `agentcore_classification_agent_arn`
2. WHEN the Monitor_Script constructs log group names, THE Monitor_Script SHALL derive the log group path from the agent runtime ARN or ID using the CloudWatch log group naming convention for Bedrock AgentCore runtimes
3. THE Monitor_Script SHALL remove all hardcoded log group paths
4. THE Monitor_Script SHALL provide monitoring subcommands for the 4 agents: extraction, damage, fraud, classification
5. THE Monitor_Script SHALL remove the workflow, entity, database, and summary agent monitoring subcommands that reference non-existent agents
6. THE Monitor_Script SHALL retain the orchestrator Lambda log group monitoring option (constructing the log group name dynamically)
7. THE Monitor_Script SHALL retain the malware Lambda log group monitoring option
8. WHEN the Monitor_Script displays usage help, THE Monitor_Script SHALL list the updated agent names and descriptions matching the nys-2026 architecture

### Requirement 3: Updated Stage 0 Deploy Script Banner and Outputs

**User Story:** As a demo operator, I want `code-talk/stage0-deploy.sh` to reflect the Python zip/S3 packaging model instead of Docker/ECR, so that the script output accurately describes what was deployed.

#### Acceptance Criteria

1. THE Stage0_Deploy_Script SHALL display a banner referencing "AgentCore Agents" instead of "AgentCore ECR"
2. THE Stage0_Deploy_Script SHALL describe the packaging as Python zip packages uploaded to S3 instead of ECR repositories and Docker images
3. WHEN deployment succeeds, THE Stage0_Deploy_Script SHALL display the 4 agent runtime names: document-extraction-agent, damage-assessment-agent, fraud-detection-agent, classification-agent
4. THE Stage0_Deploy_Script SHALL remove all references to ECR repositories, Docker images, and the 5 old agent names (workflow-agent, entity-extraction-agent, fraud-validation-agent, database-insertion-agent, summary-generation-agent)
5. WHEN deployment succeeds, THE Stage0_Deploy_Script SHALL display the agent code bucket name from Terraform output `agentcore_agent_code_bucket`

### Requirement 4: Updated Stage 0 Verify Script

**User Story:** As a demo operator, I want `code-talk/stage0-verify.sh` to verify agent runtimes and the correct Bedrock model instead of checking ECR repositories and old models, so that verification reflects the actual deployed architecture.

#### Acceptance Criteria

1. THE Stage0_Verify_Script SHALL verify the existence of 4 agent runtimes (document-extraction, damage-assessment, fraud-detection, classification) instead of checking ECR repositories
2. THE Stage0_Verify_Script SHALL remove all ECR repository checks including the `ECR_REPOS` array and associated `aws ecr describe-repositories` calls
3. THE Stage0_Verify_Script SHALL verify access to the Bedrock model `global.anthropic.claude-sonnet-4-6` instead of `anthropic.claude-3-haiku-20240307-v1:0` and `anthropic.claude-3-5-sonnet-20240620-v1:0`
4. THE Stage0_Verify_Script SHALL remove the invocation tests for Claude 3 Haiku and Claude 3.5 Sonnet
5. WHEN verifying agent runtimes, THE Stage0_Verify_Script SHALL use the Terraform outputs `agentcore_document_extraction_agent_arn`, `agentcore_damage_assessment_agent_arn`, `agentcore_fraud_detection_agent_arn`, `agentcore_classification_agent_arn` to confirm the runtimes exist

### Requirement 5: Updated Stage 3 Deploy Script

**User Story:** As a demo operator, I want `code-talk/stage3-deploy.sh` to reflect the MCP gateway architecture and remove references to non-existent outputs, so that the deployment script accurately describes Stage 3.

#### Acceptance Criteria

1. THE Stage3_Deploy_Script SHALL display a banner describing "MCP Gateway + Orchestrator Lambda + DynamoDB" instead of "Agent Deployment"
2. THE Stage3_Deploy_Script SHALL remove the reference to Terraform output `agentcore_workflow_agent_runtime_id`
3. WHEN deployment succeeds, THE Stage3_Deploy_Script SHALL display the claims table name from Terraform output `agentcore_claims_table_name`
4. WHEN deployment succeeds, THE Stage3_Deploy_Script SHALL display the clean bucket name from Terraform output `malware_clean_bucket_name`
5. THE Stage3_Deploy_Script SHALL remove the comment "Note: Docker images were built in Stage 0"

### Requirement 6: Updated Stage 3 Test Script

**User Story:** As a demo operator, I want `code-talk/stage3-test.sh` to use the correct Terraform outputs and display updated monitoring labels, so that the test script works with the nys-2026 architecture.

#### Acceptance Criteria

1. THE Stage3_Test_Script SHALL remove the reference to Terraform output `agentcore_workflow_agent_runtime_id`
2. THE Stage3_Test_Script SHALL not include `WORKFLOW_AGENT_ID` in the validation check for required outputs
3. WHEN monitoring agent logs, THE Stage3_Test_Script SHALL use the labels: [EXTRACTION], [DAMAGE], [FRAUD], [CLASSIFICATION], [ORCHESTRATOR]
4. THE Stage3_Test_Script SHALL remove the old monitoring labels: [WORKFLOW], [ENTITY], [DATABASE], [SUMMARY]
5. WHEN color-coding log output, THE Stage3_Test_Script SHALL map agent log groups to the new labels based on agent name patterns: document_extraction → [EXTRACTION], damage_assessment → [DAMAGE], fraud_detection → [FRAUD], classification → [CLASSIFICATION]
6. THE Stage3_Test_Script SHALL add an [ORCHESTRATOR] label for the claims orchestrator Lambda log group

### Requirement 7: Updated DEMO-SETUP.md

**User Story:** As a demo operator, I want `code-talk/DEMO-SETUP.md` to describe the Python zip/S3 packaging and correct Bedrock model, so that the setup guide matches the actual deployment process.

#### Acceptance Criteria

1. THE Demo_Setup_Doc SHALL describe Stage 0 as deploying "4 AgentCore agent runtimes (packaged with uv pip install + zip, uploaded to S3)" instead of "ECR repositories and Docker images"
2. THE Demo_Setup_Doc SHALL remove all references to ECR, Docker, and Docker build times
3. THE Demo_Setup_Doc SHALL reference the Bedrock model `global.anthropic.claude-sonnet-4-6` (Claude Sonnet 4.6) instead of Claude 3 Haiku and Claude 3.5 Sonnet
4. THE Demo_Setup_Doc SHALL describe Stage 3 as deploying "MCP gateway + claims_reader Lambda + orchestrator Lambda + DynamoDB" instead of "Bedrock agents (uses Docker images from Stage 0)"
5. THE Demo_Setup_Doc SHALL update the Bedrock model access instructions to reference enabling `global.anthropic.claude-sonnet-4-6` instead of the two old models

### Requirement 8: Updated README.md Monitoring Section

**User Story:** As a developer reading the README, I want the monitoring section to describe the current agent labels and pipeline, so that the documentation matches the deployed system.

#### Acceptance Criteria

1. THE README_Doc SHALL remove the `[wip]` tag from the "Monitoring Agent Activity" section heading
2. THE README_Doc SHALL remove the note stating that prefixes predate the 4-agent refactor and that the test script is scheduled for a separate update
3. THE README_Doc SHALL list the updated monitoring labels: [EXTRACTION], [DAMAGE], [FRAUD], [CLASSIFICATION], [ORCHESTRATOR]
4. THE README_Doc SHALL describe each label with its corresponding agent function: EXTRACTION for document extraction, DAMAGE for damage assessment, FRAUD for fraud detection, CLASSIFICATION for claim routing, ORCHESTRATOR for pipeline coordination
5. THE README_Doc SHALL remove the old monitoring labels: [WORKFLOW], [ENTITY], [FRAUD], [DATABASE], [SUMMARY]
