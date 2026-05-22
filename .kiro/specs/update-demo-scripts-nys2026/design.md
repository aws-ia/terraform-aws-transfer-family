# Design Document

## Overview

This feature updates 7 shell scripts and 2 markdown documents in `examples/sftp-automated-workflows-agentcore/` to align with the nys-2026 architecture refactor. The changes are purely presentational and operational — no Terraform infrastructure changes are required. All scripts transition from hardcoded values and old agent names to dynamic Terraform output lookups and the new 4-agent + Lambda orchestrator architecture.

## Architecture

The scripts form a layered dependency on Terraform outputs and AWS CLI commands. No script modifies infrastructure — they only read state and display information or tail logs.

### Key Architectural Changes Reflected

| Aspect | Old (pre-nys-2026) | New (nys-2026) |
|--------|---------------------|----------------|
| Agent count | 5 Docker agents | 4 Python zip agents + 1 Lambda orchestrator |
| Packaging | Docker/ECR | Python zip (uv pip install) → S3 |
| Agent names | workflow, entity-extraction, fraud-validation, database-insertion, summary-generation | document-extraction, damage-assessment, fraud-detection, classification |
| Orchestration | workflow-agent (AgentCore) | claims-orchestrator (Lambda) |
| Bedrock model | Claude 3 Haiku + Claude 3.5 Sonnet | Claude Sonnet 4.6 (`global.anthropic.claude-sonnet-4-6`) |
| Stage 3 components | Agent deployment (Docker images from Stage 0) | MCP Gateway + claims_reader Lambda + orchestrator Lambda + DynamoDB |
| Removed output | `agentcore_workflow_agent_runtime_id` | N/A |

## Components and Interfaces

### Component 1: `demo/run_demo.sh`

**Responsibility**: Display demo instructions and SFTP connection details dynamically.

**Changes**:
- Replace hardcoded SFTP connection block with dynamic lookups
- Add `terraform output` calls for `transfer_server_endpoint`, `cognito_username`, `cognito_password_secret_arn`
- Add `aws secretsmanager get-secret-value` call to retrieve password
- Update pipeline step descriptions to match 4-agent + orchestrator architecture
- Update monitoring option references to new agent names

**Pattern**:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSFER_SERVER_ENDPOINT=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_server_endpoint 2>/dev/null || echo "")
COGNITO_USERNAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_username 2>/dev/null || echo "")
COGNITO_PASSWORD_SECRET_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_password_secret_arn 2>/dev/null || echo "")
PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$COGNITO_PASSWORD_SECRET_ARN" --query SecretString --output text 2>/dev/null | jq -r .password 2>/dev/null)
```

### Component 2: `demo/monitor_agents.sh`

**Responsibility**: Tail CloudWatch log groups for agent runtimes and infrastructure Lambdas.

**Changes**:
- Remove all hardcoded log group paths
- Add dynamic log group discovery from Terraform output ARNs
- Derive log group names from runtime ARNs using the AgentCore naming convention
- Replace subcommands: `workflow|entity|fraud|database|summary` → `extraction|damage|fraud|classification`
- Add `orchestrator` subcommand for the claims-orchestrator Lambda
- Retain `malware` subcommand

**Log Group Derivation Logic**:

AgentCore runtime log groups follow the pattern `/aws/bedrock-agentcore/runtimes/{runtime_name}`. The runtime name can be extracted from the ARN (last segment after the final `/` or `:`) or discovered via `aws logs describe-log-groups` with a prefix filter.

```bash
# Approach: Use describe-log-groups with the agent name prefix
# Agent runtimes are named: tf-demo-{agent-name}
# So log groups will contain the runtime name in the path

EXTRACTION_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_document_extraction_agent_arn 2>/dev/null || echo "")
# Extract runtime name from ARN: arn:aws:bedrock-agentcore:region:account:runtime/RUNTIME_NAME
EXTRACTION_RUNTIME=$(echo "$EXTRACTION_ARN" | awk -F'/' '{print $NF}')
# Discover log group
EXTRACTION_LOG_GROUP=$(aws logs describe-log-groups \
    --log-group-name-prefix "/aws/bedrock-agentcore/runtimes/$EXTRACTION_RUNTIME" \
    --query 'logGroups[0].logGroupName' --output text 2>/dev/null || echo "")
```

**Subcommand mapping**:
| Subcommand | Agent/Resource | Log Group Source |
|------------|---------------|-----------------|
| `extraction` | document-extraction-agent | Derived from `agentcore_document_extraction_agent_arn` |
| `damage` | damage-assessment-agent | Derived from `agentcore_damage_assessment_agent_arn` |
| `fraud` | fraud-detection-agent | Derived from `agentcore_fraud_detection_agent_arn` |
| `classification` | classification-agent | Derived from `agentcore_classification_agent_arn` |
| `orchestrator` | claims-orchestrator Lambda | `/aws/lambda/tf-demo-claims-orchestrator` |
| `malware` | malware scanner Lambda | Existing pattern (retained) |

### Component 3: `code-talk/stage0-deploy.sh`

**Responsibility**: Deploy Stage 0 infrastructure and display results.

**Changes**:
- Update banner: "Identity Foundation + AgentCore Agents" (was "AgentCore ECR")
- Update description comment: "Python zip packages uploaded to S3" (was "ECR repositories and Docker images")
- Replace ECR/Docker output section with agent runtime names and code bucket
- Display `agentcore_agent_code_bucket` output
- List 4 agent runtime names: document-extraction-agent, damage-assessment-agent, fraud-detection-agent, classification-agent

### Component 4: `code-talk/stage0-verify.sh`

**Responsibility**: Verify environment setup after Stage 0 deployment.

**Changes**:
- Remove entire "Checking ECR repositories" section (ECR_REPOS array + describe-repositories loop)
- Add "Checking AgentCore agent runtimes" section using the 4 ARN terraform outputs
- Replace Bedrock model checks: remove Claude 3 Haiku and Claude 3.5 Sonnet, add `global.anthropic.claude-sonnet-4-6`
- Remove model invocation tests for old models (cross-region model IDs don't support direct invoke-model)
- Update manual configuration section to reference the new model

**Agent Runtime Verification Pattern**:
```bash
EXTRACTION_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_document_extraction_agent_arn 2>/dev/null || echo "")
if [ -n "$EXTRACTION_ARN" ] && [ "$EXTRACTION_ARN" != "null" ]; then
    check_result "pass" "Document extraction agent runtime exists"
else
    check_result "fail" "Document extraction agent runtime not found"
fi
```

### Component 5: `code-talk/stage3-deploy.sh`

**Responsibility**: Deploy Stage 3 infrastructure and display results.

**Changes**:
- Update banner: "MCP Gateway + Orchestrator Lambda + DynamoDB" (was "Agent Deployment")
- Remove header comment about Docker images
- Remove `WORKFLOW_AGENT_ID` terraform output lookup and display
- Retain `CLAIMS_TABLE` and `CLEAN_BUCKET` displays
- Add display of orchestrator Lambda name

### Component 6: `code-talk/stage3-test.sh`

**Responsibility**: Test AI claims processing end-to-end with SFTP upload and log monitoring.

**Changes**:
- Remove `WORKFLOW_AGENT_ID` from terraform output extraction and validation
- Update the `case` statement for log color-coding:
  - `*document_extraction*` → `[EXTRACTION]` (BLUE)
  - `*damage_assessment*` → `[DAMAGE]` (MAGENTA)
  - `*fraud_detection*` → `[FRAUD]` (RED)
  - `*classification*` → `[CLASSIFICATION]` (YELLOW)
- Add orchestrator Lambda log group monitoring with `[ORCHESTRATOR]` label (CYAN)
- Remove old labels: [WORKFLOW], [ENTITY], [DATABASE], [SUMMARY]

### Component 7: `code-talk/DEMO-SETUP.md`

**Responsibility**: Detailed setup guide for the demo.

**Changes**:
- Update Stage 0 description: "4 AgentCore agent runtimes (packaged with uv pip install + zip, uploaded to S3)"
- Remove all ECR/Docker/build time references
- Update Bedrock model section: reference `global.anthropic.claude-sonnet-4-6` (Claude Sonnet 4.6)
- Update Stage 3 description: "MCP gateway + claims_reader Lambda + orchestrator Lambda + DynamoDB"
- Update model access instructions

### Component 8: `README.md` (Monitoring Section)

**Responsibility**: Document monitoring labels for developers.

**Changes**:
- Remove `[wip]` from section heading
- Remove the "Note" about prefixes predating the refactor
- Replace label list with:
  - 🔵 **[EXTRACTION]** — document extraction activity
  - 🟣 **[DAMAGE]** — damage assessment analysis
  - 🔴 **[FRAUD]** — fraud detection checks
  - 🟡 **[CLASSIFICATION]** — claim routing decisions
  - 🟢 **[ORCHESTRATOR]** — pipeline coordination

## Testing Strategy

Since these are shell scripts and markdown documents, testing is primarily done through:

1. **Static analysis (grep-based)**: Verify absence of hardcoded values, old agent names, ECR/Docker references, and removed Terraform outputs
2. **Structural validation**: Verify scripts contain the expected subcommands, labels, and terraform output calls
3. **Property-based tests**: Validate the pure-function transformations (ARN → log group path, terraform outputs → displayed commands, agent name patterns → labels)

Unit tests should mock `terraform output` and `aws` CLI calls to verify script behavior without requiring deployed infrastructure.

## Interfaces

### Terraform Output Interface

All scripts consume Terraform outputs via `terraform -chdir="$SCRIPT_DIR" output -raw <output_name>`. The available outputs used by the updated scripts:

| Output Name | Type | Used By |
|-------------|------|---------|
| `transfer_server_endpoint` | string | run_demo.sh, stage3-test.sh |
| `cognito_username` | string | run_demo.sh, stage3-test.sh |
| `cognito_password_secret_arn` | string | run_demo.sh, stage3-test.sh |
| `agentcore_document_extraction_agent_arn` | string | monitor_agents.sh, stage0-verify.sh |
| `agentcore_damage_assessment_agent_arn` | string | monitor_agents.sh, stage0-verify.sh |
| `agentcore_fraud_detection_agent_arn` | string | monitor_agents.sh, stage0-verify.sh |
| `agentcore_classification_agent_arn` | string | monitor_agents.sh, stage0-verify.sh |
| `agentcore_agent_code_bucket` | string | stage0-deploy.sh |
| `agentcore_claims_table_name` | string | stage3-deploy.sh, stage3-test.sh |
| `malware_clean_bucket_name` | string | stage3-deploy.sh, stage3-test.sh |

### AWS CLI Interface

| Command | Purpose | Used By |
|---------|---------|---------|
| `aws secretsmanager get-secret-value` | Retrieve SFTP password | run_demo.sh, stage3-test.sh |
| `aws logs describe-log-groups` | Discover agent log groups | monitor_agents.sh |
| `aws logs filter-log-events` | Tail agent logs | monitor_agents.sh, stage3-test.sh |

## Data Models

No new data models are introduced. The scripts consume existing Terraform outputs and AWS resource identifiers.

### Agent Name to Log Label Mapping

```bash
# Pattern matching in case statements:
# Log group path contains the runtime name which includes the agent name
case "$AGENT_NAME" in
    *document_extraction*|*document-extraction*)
        LABEL="EXTRACTION"; COLOR="$BLUE" ;;
    *damage_assessment*|*damage-assessment*)
        LABEL="DAMAGE"; COLOR="$MAGENTA" ;;
    *fraud_detection*|*fraud-detection*)
        LABEL="FRAUD"; COLOR="$RED" ;;
    *classification*)
        LABEL="CLASSIFICATION"; COLOR="$YELLOW" ;;
    *claims-orchestrator*|*orchestrator*)
        LABEL="ORCHESTRATOR"; COLOR="$CYAN" ;;
    *)
        LABEL="AGENT"; COLOR="$GREEN" ;;
esac
```

## Error Handling

All scripts follow the existing error handling pattern:
- `set -e` for exit on error
- `2>/dev/null || echo ""` for graceful terraform output failures
- Validation checks before proceeding (e.g., checking required outputs are non-empty)
- Clear error messages with color-coded output

Scripts that fail to retrieve required Terraform outputs will display an error message and exit with code 1, directing the user to deploy the prerequisite stage first.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Dynamic SFTP command reflects Terraform outputs

*For any* pair of (server_endpoint, username) values returned by `terraform output`, the Run_Demo_Script's displayed SFTP connection command SHALL contain both the server_endpoint and username values verbatim.

**Validates: Requirements 1.4**

### Property 2: Agent name pattern to monitoring label mapping

*For any* CloudWatch log group name containing one of the agent name patterns (document_extraction, damage_assessment, fraud_detection, classification, claims-orchestrator), the Stage3_Test_Script's case statement SHALL map it to exactly one of the labels [EXTRACTION], [DAMAGE], [FRAUD], [CLASSIFICATION], [ORCHESTRATOR] respectively, with no ambiguity.

**Validates: Requirements 6.3, 6.5, 6.6**

### Property 3: Log group derivation from ARN

*For any* valid Bedrock AgentCore runtime ARN of the form `arn:aws:bedrock-agentcore:{region}:{account}:runtime/{runtime_name}`, the Monitor_Script's log group discovery SHALL produce a log group path matching the prefix `/aws/bedrock-agentcore/runtimes/{runtime_name}`.

**Validates: Requirements 2.2**
