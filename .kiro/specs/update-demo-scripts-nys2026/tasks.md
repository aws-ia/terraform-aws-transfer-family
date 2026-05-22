# Implementation Plan: Update Demo Scripts for nys-2026 Architecture

## Overview

Update 7 shell scripts and 2 markdown documents in `examples/sftp-automated-workflows-agentcore/` to align with the nys-2026 architecture refactor. All changes transition from hardcoded values and old 5-agent Docker/ECR architecture to dynamic Terraform output lookups and the new 4-agent + Lambda orchestrator architecture.

## Tasks

- [x] 1. Update `demo/run_demo.sh` with dynamic connection details
  - [x] 1.1 Replace hardcoded SFTP connection block with dynamic Terraform output lookups
    - Add `SCRIPT_DIR` variable pointing to parent directory
    - Add `terraform -chdir` calls for `transfer_server_endpoint`, `cognito_username`, `cognito_password_secret_arn`
    - Add `aws secretsmanager get-secret-value` call to retrieve password
    - Display dynamically retrieved SFTP connection command using resolved values
    - Remove the hardcoded `sftp anycompany-repairs@s-a58dd1620ef943f4b...` block and password
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 1.2 Update pipeline steps and monitoring references to nys-2026 architecture
    - Replace pipeline steps (entity extraction, fraud validation, database insertion, summary report) with: document extraction, damage assessment, fraud detection, classification, summary generation
    - Replace monitoring option agent names from `{workflow|entity|fraud|database|summary}` to `{extraction|damage|fraud|classification|orchestrator}`
    - _Requirements: 1.6, 1.7_

- [x] 2. Update `demo/monitor_agents.sh` with dynamic log group discovery
  - [x] 2.1 Replace hardcoded log group paths with dynamic ARN-based discovery
    - Remove all hardcoded `WORKFLOW`, `ENTITY`, `FRAUD`, `DATABASE`, `SUMMARY` log group variables
    - Add `SCRIPT_DIR` variable and Terraform output lookups for the 4 agent ARNs
    - Implement log group derivation: extract runtime name from ARN, then use `aws logs describe-log-groups` with prefix filter
    - Construct orchestrator Lambda log group dynamically (e.g. `/aws/lambda/tf-demo-claims-orchestrator`)
    - Retain malware Lambda log group (construct dynamically or retain existing pattern)
    - _Requirements: 2.1, 2.2, 2.3, 2.6, 2.7_

  - [x] 2.2 Update subcommands and usage help for 4-agent architecture
    - Replace case statement subcommands: remove `workflow`, `entity`, `database`, `summary`; add `extraction`, `damage`, `classification`, `orchestrator`
    - Update the `all` command output to list the new subcommands
    - Update usage/help text with new agent names and descriptions
    - _Requirements: 2.4, 2.5, 2.8_

- [x] 3. Update `code-talk/stage0-deploy.sh` banner and outputs
  - [x] 3.1 Update banner, header comment, and deployment output section
    - Change banner from "Identity Foundation + AgentCore ECR" to "Identity Foundation + AgentCore Agents"
    - Update header comment: replace "ECR repositories and Docker images for AgentCore agents (~2 min)" with "Python zip packages uploaded to S3 for AgentCore agents"
    - Replace ECR/Docker output section with 4 agent runtime names: document-extraction-agent, damage-assessment-agent, fraud-detection-agent, classification-agent
    - Add display of `agentcore_agent_code_bucket` Terraform output
    - Remove all references to ECR repositories, Docker images, and old 5 agent names
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 4. Update `code-talk/stage0-verify.sh` for agent runtimes and new Bedrock model
  - [x] 4.1 Replace ECR repository checks with agent runtime verification
    - Remove entire "Checking ECR repositories" section (ECR_REPOS array, describe-repositories loop, all ECR-related output)
    - Add "Checking AgentCore agent runtimes" section
    - Use Terraform outputs `agentcore_document_extraction_agent_arn`, `agentcore_damage_assessment_agent_arn`, `agentcore_fraud_detection_agent_arn`, `agentcore_classification_agent_arn` to verify runtimes exist
    - _Requirements: 4.1, 4.2, 4.5_

  - [x] 4.2 Replace Bedrock model checks with Claude Sonnet 4.6
    - Remove Claude 3 Haiku and Claude 3.5 Sonnet model checks and invocation tests
    - Add check for `global.anthropic.claude-sonnet-4-6` model access
    - Remove invocation tests (cross-region model IDs don't support direct invoke-model)
    - Update manual configuration section to reference the new model
    - _Requirements: 4.3, 4.4_

- [x] 5. Checkpoint - Verify scripts are syntactically valid
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Update `code-talk/stage3-deploy.sh` for MCP gateway architecture
  - [x] 6.1 Update banner, remove old output references, add new outputs
    - Change banner from "AI Claims Processing (Agent Deployment)" to "AI Claims Processing (MCP Gateway + Orchestrator Lambda + DynamoDB)"
    - Remove header comment "Note: Docker images were built in Stage 0"
    - Remove `WORKFLOW_AGENT_ID` terraform output lookup and its display section
    - Retain `CLAIMS_TABLE` and `CLEAN_BUCKET` displays
    - Add display of orchestrator Lambda name if available
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 7. Update `code-talk/stage3-test.sh` for new agent labels and outputs
  - [x] 7.1 Remove workflow agent references and update validation
    - Remove `WORKFLOW_AGENT_ID` terraform output extraction line
    - Remove `WORKFLOW_AGENT_ID` from the validation check (the `if [ -z ... ]` condition)
    - Remove display of "Workflow Agent ID" in the monitoring section
    - _Requirements: 6.1, 6.2_

  - [x] 7.2 Update log monitoring case statements with new agent labels
    - In both monitoring loops, replace the case statement patterns:
      - `*workflow*` → remove
      - `*entity*` → `*document_extraction*` with label `[EXTRACTION]` (BLUE)
      - `*validation*|*fraud*` → `*fraud_detection*` with label `[FRAUD]` (RED)
      - `*database*` → remove
      - `*summary*` → remove
      - Add `*damage_assessment*` with label `[DAMAGE]` (MAGENTA)
      - Add `*classification*` with label `[CLASSIFICATION]` (YELLOW)
    - Add orchestrator Lambda log group monitoring with `[ORCHESTRATOR]` label (CYAN)
    - _Requirements: 6.3, 6.4, 6.5, 6.6_

- [x] 8. Update `code-talk/DEMO-SETUP.md` documentation
  - [x] 8.1 Update Stage 0 and Stage 3 descriptions and Bedrock model references
    - Replace Stage 0 description: "4 AgentCore agent runtimes (packaged with uv pip install + zip, uploaded to S3)" instead of ECR/Docker references
    - Remove all references to ECR, Docker, Docker build times
    - Update Bedrock model section: reference `global.anthropic.claude-sonnet-4-6` (Claude Sonnet 4.6) instead of Claude 3 Haiku and Claude 3.5 Sonnet
    - Update Stage 3 description: "MCP gateway + claims_reader Lambda + orchestrator Lambda + DynamoDB" instead of "Bedrock agents (uses Docker images from Stage 0)"
    - Update model access instructions to reference enabling `global.anthropic.claude-sonnet-4-6`
    - Remove the "Note: Stage 3 deploys the Bedrock agents only. Docker images were already built in Stage 0, saving ~2 minutes." line
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 9. Update `README.md` monitoring section
  - [x] 9.1 Update the "Monitoring Agent Activity" section with new labels
    - Remove `[wip]` from the section heading
    - Remove the "Note" paragraph about prefixes predating the 4-agent refactor
    - Replace label list with: [EXTRACTION] (document extraction), [DAMAGE] (damage assessment), [FRAUD] (fraud detection), [CLASSIFICATION] (claim routing), [ORCHESTRATOR] (pipeline coordination)
    - Remove old labels: [WORKFLOW], [ENTITY], [FRAUD], [DATABASE], [SUMMARY]
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 10. Final checkpoint - Review all changes for consistency
  - Ensure all tests pass, ask the user if questions arise.
  - Verify no remaining references to: ECR, Docker, workflow-agent, entity-extraction-agent, fraud-validation-agent, database-insertion-agent, summary-generation-agent, `agentcore_workflow_agent_runtime_id`, Claude 3 Haiku, Claude 3.5 Sonnet

## Notes

- All changes are to shell scripts and markdown files — no Terraform infrastructure changes
- Scripts use `terraform -chdir="$SCRIPT_DIR" output -raw <name>` pattern for dynamic lookups
- The design document specifies Bash as the implementation language (existing scripts are all Bash)
- Property tests validate ARN-to-log-group derivation and agent-name-to-label mapping logic
- Each task references specific requirements for traceability

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "3.1", "4.1", "6.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "4.2", "7.1"] },
    { "id": 2, "tasks": ["2.2", "7.2", "8.1", "9.1"] }
  ]
}
```
