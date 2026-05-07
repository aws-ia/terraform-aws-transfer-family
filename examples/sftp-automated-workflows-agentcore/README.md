# SFTP Automated Workflows with AI Claims Processing

This example demonstrates a complete end-to-end solution for secure file transfer, automated malware protection, and AI-powered document processing using AWS Transfer Family, Amazon GuardDuty, and Amazon Bedrock AgentCore.

## Solution Overview

This **proof-of-concept** implements an end-to-end **P&C (Property & Casualty) insurance claim intake pipeline** of the kind carriers run when body shops, contractors, and partner agents submit First Notice of Loss (FNOL) packages in bulk. The sample data is a property damage claim — a ZIP containing a submission form, policy document, damage photos, and a repair estimate document — but the extraction schemas, damage types, fraud rules, and classification thresholds are all configuration-driven, so the same pipeline adapts to other P&C lines without touching the Terraform or the orchestration Lambda.

The flow mirrors how P&C carriers process a claim:

1. **Intake**: a partner agent uploads a claim ZIP via SFTP using custom (Cognito-backed) authentication — the typical bulk-submission channel for repair-network partners.
2. **Malware scan**: GuardDuty scans every upload and routes clean files to a processing bucket before any AI runs — no untrusted attachment ever reaches the extraction agents.
3. **Document understanding**: the Document Extraction agent classifies each artifact (`submission-form`, `policy-document`, `photo`, `repair-estimate`) and extracts structured fields (claimant details, policy number, coverage limit, deductible, incident description, line items) with per-field confidence scores.
4. **Independent damage assessment**: a vision-capable agent classifies damage type and severity from each photo, then produces its own cost estimate from a static repair-cost reference (`agent-source-code/damage_assessment_agent/config/repair_costs.json`). It deliberately does **not** trust the body shop's estimate, so inflation can be quantified.
5. **Fraud risk profile**: the Fraud Detection agent emits a `risk_score`, `risk_level`, and per-rule flags covering coverage-limit breaches, deductible checks, policy validity (effective/expiration dates), estimate deviations vs. the independent assessment, and photo-manipulation signals (Bedrock vision). Each flag quotes the specific claim-data values that triggered it, giving SIU reviewable evidence.
6. **Straight-through routing (STP)**: the Classification agent routes each claim to `approved`, `requires_review`, or `rejected` using threshold-based rules — clean low-risk claims can be auto-settled, ambiguous ones land in the adjuster queue, and clear policy violations or high-risk patterns are rejected for investigation. The agent does not re-weight the fraud score; it only applies the routing thresholds.
7. **Adjuster and SIU review**: Claims Reviewers (adjusters, read access to processed claims) and Claims Administrators (SIU / claims management, full access) access processed claims through a Transfer Family web app backed by role-separated S3 Access Grants. Each claim carries a self-contained HTML summary for quick triage.

**Built with Terraform and AWS Transfer Family modules**, this proof-of-concept provides infrastructure-as-code that can be deployed incrementally across 5 stages for learning and evaluation purposes. The modular Terraform architecture uses the official AWS Transfer Family modules to provision secure file transfer infrastructure, making it easy to adapt to a specific carrier's intake channels, policy administration system, and claim-handling workflow.

> **Note**: This is demonstration code intended for learning and evaluation. Production use in a regulated P&C context requires additional work on security hardening, PII handling and encryption in transit/at rest, audit logging for claim-handling actions, state-level regulatory compliance (e.g. prompt-payment laws, NAIC model laws on data retention and unfair claims settlement practices), and integration with existing policy administration, claims management, and SIU case-management systems.

**Key capabilities demonstrated**:
- Secure bulk FNOL intake via SFTP from contractors and partner agents
- Automated malware scanning on every submission before it touches the AI pipeline
- Structured extraction from P&C claim artifacts: submission forms, policy documents, damage photos, repair estimates
- Independent damage classification and cost estimation — does not rely on the claimant's repair estimate, so inflation is measurable
- Coverage-aware fraud risk scoring with per-rule flags and quoted evidence strings (for SIU review and audit trails)
- Photo-manipulation detection on every image via Bedrock vision
- Straight-through routing: `approved` / `requires_review` / `rejected`, with the fraud risk score carried through
- Self-contained HTML claim summary per claim for adjuster and SIU triage
- Role-separated web access for Claims Reviewers (adjusters) and Claims Administrators (SIU / claims management)

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
│   ├── stage0-deploy.sh            # Deploy identity foundation + Custom IDP + agent runtimes
│   ├── stage0-verify.sh            # Verify environment setup
│   ├── stage1-deploy.sh            # Deploy Transfer server
│   ├── stage1-test.sh              # Test SFTP upload
│   ├── stage2-deploy.sh            # Deploy malware protection
│   ├── stage2-test.sh              # Test malware scanning
│   ├── stage3-deploy.sh            # Deploy AI orchestration layer
│   ├── stage3-test.sh              # Test claims processing
│   ├── stage4-deploy.sh            # Deploy web application
│   ├── zip-claims.sh               # Utility to zip claim files
│   ├── cleanup.sh                  # Cleanup all resources
│   └── DEMO-SETUP.md               # Detailed setup guide
├── data/                            # Sample claim files
│   ├── claim-1/                    # Fraudulent claim (mismatched damage)
│   ├── claim-2/                    # Legitimate claim
│   ├── claim-3/                    # Additional sample claim
│   └── zipped/                     # Generated claim-N.zip files for testing
├── agent-source-code/               # Python source for agents and orchestrator
│   ├── classification_agent/       # AgentCore — threshold-based routing
│   ├── damage_assessment_agent/    # AgentCore — photo-based damage scoring
│   ├── document_extraction_agent/  # AgentCore — structured PDF/image extraction
│   ├── fraud_detection_agent/      # AgentCore — LLM-driven fraud analysis
│   └── claims-orchestrator/        # Lambda — drives the 4 agents through pipeline stages
├── stage0-foundation.tf             # Identity Center, S3 Access Grants, Cognito, Custom IDP
├── stage0-agentcore-agents.tf       # 4 AgentCore agent runtimes (packaged via uv pip + zip → S3)
├── stage1-transfer-server.tf        # Transfer Family SFTP server + S3 upload bucket
├── stage2-malware-protection.tf     # GuardDuty malware scanning + routing buckets
├── stage3-agentcore.tf              # AI orchestration: MCP gateway + claims_reader Lambda + orchestrator Lambda + DynamoDB
├── stage4-webapp.tf                 # Web application
├── stage0.tfvars                    # Stage 0 configuration
├── stage1.tfvars                    # Stage 1 configuration
├── stage2.tfvars                    # Stage 2 configuration
├── stage3.tfvars                    # Stage 3 configuration
├── stage4.tfvars                    # Stage 4 configuration
└── modules/                         # Reusable Terraform modules
    ├── agentcore-agent/            # Per-agent runtime + IAM + build + S3 upload
    ├── claims-orchestrator/        # Orchestrator Lambda + IAM + EventBridge trigger
    └── cognito-hosted-ui/          # Cognito user pool + Managed Login + optional landing page
```

## Architecture Overview

The solution consists of 5 incremental stages that build upon each other:

### Stage 0: Identity Foundation + Custom IDP + AgentCore Agents
**"Identity and authentication foundation, plus the agent runtimes themselves"**
- IAM Identity Center with users and groups
- S3 Access Grants instance
- Cognito user pool for external authentication
- Custom IDP Lambda (built with CodeBuild; consumed by the stage 1 Transfer Server)
- 4 AgentCore agent runtimes (document extraction, damage assessment, fraud detection, classification) — packaged with `uv pip install` + zip, uploaded to S3, and registered. No gateway wiring yet, no clean-bucket access yet.

### Stage 1: Transfer Server with External Users
**"Secure file transfer with custom authentication"**
- Transfer Family SFTP server
- S3 bucket for uploaded files
- DynamoDB user record wiring the `anycompany-repairs` Cognito user to the Custom IDP (Custom IDP itself is built in stage 0)

### Stage 2: Malware Protection
**"Automated malware scanning on upload"**
- GuardDuty Malware Protection
- Automatic scanning of uploaded files
- Clean and quarantine buckets
- File routing based on scan results

### Stage 3: AI Claims Processing
**"Orchestration layer that drives the stage 0 agents"**
- MCP gateway + `claims_reader` Lambda — tool backend for 3 of the 4 agents (damage assessment, fraud detection, classification)
- Claims orchestrator Lambda — triggered by `Object Created` on the clean bucket, runs the 4 agents and generate the summary (in HTML) through a 5-stage pipeline
- DynamoDB table for claim records
- Self-contained HTML summary per claim, written by the orchestrator's final stage to `s3://<clean-bucket>/<claim_id>/summary.html` (inline CSS, no external assets) — ready for adjuster/SIU review in stage 4
- In-place update to the 3 gateway-using agents: `invoke-gateway` IAM + `AGENTCORE_GATEWAY_URL` env var
- Consumes the 4 AgentCore agent runtimes that were packaged and registered in stage 0 — no new agent deployment happens here

### Stage 4: Web Access for Internal Users
**"Complete solution with web-based file access"**
- AWS Transfer Family Web Apps
- S3 Access Grants for fine-grained permissions
- Internal users (claims-reviewer, claims-administrator)
- Role-based access to processed claims
- Browser-based viewing of each claim's artifacts, including opening `{claim_id}/summary.html` directly in the web app for adjuster or SIU triage — no separate reporting tool needed

### How It All Works Together

**Automated File Processing Pipeline**:
1. **Upload**: Body shop or partner agent uploads a claim ZIP to the SFTP upload bucket via Transfer Family
2. **Scan**: GuardDuty Malware Protection scans the upload in place
3. **Route**: Clean ZIPs are moved to the processing (clean) bucket; infected files go to the quarantine bucket; errors go to the errors bucket
4. **Trigger**: `Object Created` on the clean bucket (filtered to `*.zip`) fires an EventBridge rule that invokes the claims orchestrator Lambda
5. **Unzip + index**: Orchestrator unzips the archive, lays out files under a `claim-{id}/` prefix in the clean bucket, and creates the initial DynamoDB record
6. **Process**: Orchestrator runs the 4 AgentCore agents sequentially — document extraction → damage assessment → fraud detection → classification — persisting each stage's output to DynamoDB
7. **Summarize**: Final orchestrator stage renders a self-contained HTML report from the DynamoDB record and writes it to `s3://<clean-bucket>/<claim_id>/summary.html`
8. **Route outcome**: Claim is marked `approved`, `requires_review`, or `rejected` by the Classification agent and the status is set to `completed` in DynamoDB
9. **Review**: Claims Reviewers (adjusters) and Claims Administrators (SIU / claims management) browse to the claim in the Transfer Family web app, view the artifacts, and open `summary.html` directly in the browser

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

### Automated Deployment and Testing

All deployment and testing scripts are located in the `code-talk/` directory. These scripts automate the entire process with built-in validation and helpful output.

#### Step 1: Deploy and Verify Stage 0 (Identity Foundation)

```bash
cd code-talk

# Deploy identity infrastructure, Custom IDP, and AgentCore agent runtimes
./stage0-deploy.sh

# Verify environment setup
./stage0-verify.sh
```

**What this does**:
- Deploys IAM Identity Center, Cognito, S3 Access Grants
- Builds the Custom IDP Lambda via CodeBuild
- Packages the 4 AgentCore agents (`uv pip install` + zip), uploads them to S3, and registers the runtimes
- Verifies prerequisites and Bedrock model access

**Manual steps** (if verification fails):
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
- Deploys the AI orchestration layer: MCP gateway, `claims_reader` Lambda, orchestrator Lambda, and DynamoDB table
- Wires the 4 pre-built AgentCore agents (stage 0) into an S3-event-driven pipeline (orchestrator is triggered by `Object Created` on the clean bucket)
- Tests with claim-3 submission
- Monitors orchestrator and agent logs in real-time (color-coded)
- Shows processed claims in DynamoDB
- Generates a self-contained HTML summary per claim at `s3://<clean-bucket>/<claim_id>/summary.html` (inline CSS, no external assets) — ready for adjuster/SIU review in stage 4
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
2. Reset the password for each Identity Center user before first login (they are created without an initial password):
   - Open the AWS console → IAM Identity Center → Users
   - Select `claims-reviewer` → **Reset password** → choose **Generate a one-time password** (or send an email) → copy the temporary password
   - Repeat for `claims-administrator`
   - See `code-talk/DEMO-SETUP.md` Step 3B for the full walkthrough (including MFA considerations for demo users)
3. Sign in with Identity Center credentials using the temporary password, then set a new password when prompted:
   - `claims-reviewer` (read-only access to submitted and processed claims)
   - `claims-administrator` (full read/write access)
4. Browse into the `claim-3/` folder to see the original submission artifacts (submission form, policy document, damage photo, repair estimate) alongside the AI-generated `summary.html`
5. Open `summary.html` directly in the browser — it's a self-contained report (inline CSS, no external assets) showing the extracted claim fields, damage assessment, fraud risk flags, and classification outcome. No separate reporting tool needed for adjuster or SIU triage.

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

- **claim-3**: Full-artifact P&C claim matching the current 4-agent architecture (recommended for the web app walkthrough)
  - `claim-3-submission-form.pdf` — FNOL form with claimant and incident details
  - `claim-3-policy-document.pdf` — policy with coverage limit, deductible, and effective/expiration dates
  - `claim-3-photo.jpg` — damage photo
  - `claim-3-repair-estimate.pdf` — repair estimate
  - Exercises all 4 agents end-to-end: document extraction (across 3 distinct document types), damage assessment, fraud detection, and classification

### Monitoring Agent Activity [wip]

The `stage3-test.sh` script provides real-time monitoring of agent logs with color-coded output.

> **Note**: The prefixes below reflect the current state of `stage3-test.sh`, which predates the 4-agent refactor. The agent names and pipeline shown in the **AI Agent Architecture** section below are the source of truth for what actually runs — the test script is scheduled for a separate update to match.

- 🟣 **[WORKFLOW]** — orchestration output
- 🔵 **[ENTITY]** — extraction activity
- 🔴 **[FRAUD]** — fraud/damage checks
- 🟡 **[DATABASE]** — DynamoDB writes
- 🟢 **[SUMMARY]** — summary generation

Press **Ctrl+C** during monitoring to skip to the next step.

## Details about the AI Agent Architecture

The solution uses **4 specialized AI agents plus 1 Lambda orchestrator**. All four agents are built with the [STRANDS framework](https://github.com/strands-agents/sdk) and run on Amazon Bedrock AgentCore using Claude Sonnet 4.6 (`global.anthropic.claude-sonnet-4-6` by default; configurable per agent via the `bedrock_model_id` variable on `modules/agentcore-agent`). They are packaged as Python zips (`uv pip install` + `zip`) and uploaded to S3 in stage 0 — no Docker images or ECR.

Python source lives under `agent-source-code/`:

```
agent-source-code/
├── classification_agent/            # AgentCore — routing (approved / requires_review / rejected)
├── damage_assessment_agent/         # AgentCore — photo analysis + cost estimation
├── document_extraction_agent/       # AgentCore — structured extraction from PDFs and photos
├── fraud_detection_agent/           # AgentCore — fraud risk scoring with configurable rule set
└── claims-orchestrator/             # Lambda  — drives the 4 agents through a 5-stage pipeline
```

**Tool backend**: 3 of the 4 agents (damage_assessment, fraud_detection, classification) reach AWS data through an **MCP gateway** backed by the `claims_reader` Lambda (deployed in stage 3). This gives them tools like `get_claim_data`, `get_claim_photos`, and `get_fraud_rules`. The 4th agent (document_extraction) reads S3 directly via boto3 and does not use the gateway.

### Claims Orchestrator (Lambda)

- **Runtime**: AWS Lambda (python3.13) — not an AgentCore agent
- **Trigger**: S3 `Object Created` on the clean bucket (via EventBridge), filtered to `*.zip` keys
- **Source**: `agent-source-code/claims-orchestrator/`

On invocation, the orchestrator unzips the incoming claim archive, lays out the files under a `claim-{id}/` prefix in the clean bucket, creates a DynamoDB record for the claim, and then runs the following pipeline stages (`stages/`):

1. **document_extraction** — invokes the Document Extraction agent runtime, parses the structured JSON response, and writes extraction results to DynamoDB.
2. **damage_assessment** — invokes the Damage Assessment agent runtime and writes damage items + cost estimate to DynamoDB.
3. **fraud_detection** — invokes the Fraud Detection agent runtime and writes the risk profile + flags to DynamoDB.
4. **classification** — invokes the Classification agent runtime, writes the routing outcome to DynamoDB, and marks the claim status `completed`.
5. **summary** — generates a self-contained HTML report directly from the DynamoDB record and writes it to S3 at `{claim_id}/summary.html`. This stage does **not** invoke an AgentCore agent; the Lambda renders the HTML itself so reviewers can open it in the Transfer Family web app or by downloading it from the console.

### 1. Document Extraction Agent

- **Source**: `agent-source-code/document_extraction_agent/`
- **Tools (boto3, no MCP gateway)**:
  - `list_claim_documents(claim_id)` — lists document keys under the claim prefix
  - `read_document(s3_key)` — reads a document and returns it as base64
- **Role**: Classifies each document as `submission-form`, `policy-document`, `photo`, or `repair-estimate`, then extracts per-type structured fields (e.g. `claimant_name`, `policy_number`, `coverage_limit`, `incident_description`) with per-field confidence scores (0.0–1.0).

### 2. Damage Assessment Agent

- **Source**: `agent-source-code/damage_assessment_agent/`
- **Tools**:
  - `analyze_photo(s3_path, claim_id)` — Bedrock vision analysis to classify damage type and severity per photo
  - MCP gateway: `get_claim_data`, `get_claim_photos`
- **Role**: For every photo on the claim, produces a damage classification and severity. Then independently builds a cost estimate using static repair-cost reference data (`config/repair_costs.json`). It deliberately does not copy the claimant's repair estimate — that is the claimant's figure, not the agent's assessment.

### 3. Fraud Detection Agent

- **Source**: `agent-source-code/fraud_detection_agent/`
- **Tools**:
  - `analyze_photo_integrity(s3_path, claim_id)` — Bedrock vision analysis for manipulation signals
  - MCP gateway: `get_claim_data`, `get_claim_photos`, `get_fraud_rules` (optional dynamic rules)
- **Role**: Produces a fraud risk profile — **not** a binary fraud/not-fraud decision. Applies a configurable rule set covering financial, temporal, document, coverage, and photo-manipulation rules (`config/rules.py` or dynamically loaded). Emits a `risk_score`, `risk_level`, and per-rule flags with detail strings that quote the specific claim-data values that triggered each flag.

### 4. Classification Agent

- **Source**: `agent-source-code/classification_agent/`
- **Tools**: MCP gateway only — no local tools
- **Role**: Reads the full claim record (submission, extractions, damage assessment, fraud assessment) and routes to `approved`, `requires_review`, or `rejected` using threshold-based condition checks. Does **not** re-weight the fraud risk score — the Fraud Detection agent already produced that. Routing rules are loaded from static config or dynamically from the gateway.

### STRANDS Framework

All four AgentCore agents are built with [STRANDS](https://github.com/strands-agents/sdk) (`strands-agents`, `strands-agents-tools`). The framework provides:

- `@tool` decorator — exposes Python functions as tools the LLM can call
- `Agent` class — wraps a `BedrockModel` with tool-calling logic and conversation management
- `BedrockAgentCoreApp` — hosts the agent as an HTTP server inside AgentCore Runtime
- MCP client support — lets an agent consume tools from an external MCP gateway (used by damage_assessment, fraud_detection, and classification)

Agents read their tool descriptions from Python docstrings, decide when to call each tool, chain multiple tool calls together, and return structured JSON that the orchestrator parses and persists to DynamoDB.

## Important Notes

1. **Stage Dependencies**: Each stage builds on the previous one. Deploy in order (0 → 1 → 2 → 3 → 4).

2. **Identity Center**: Only one Identity Center instance per AWS account. If you already have one, you may need to adjust the configuration.

3. **Bedrock Model Access**: Ensure `global.anthropic.claude-sonnet-4-6` is enabled in your AWS account before deploying Stage 0 (the stage-0 verify script checks access). This is the default model for all four AgentCore agents and is configurable via the `bedrock_model_id` variable on `modules/agentcore-agent`.

4. **Costs**: Be aware of AWS service costs for Transfer Family, GuardDuty Malware Protection, Bedrock, AgentCore, CloudWatch Logs, Lambda, S3, and DynamoDB.

5. **Cleanup**: Always clean up any infrastructure you create to avoid unnecessary charges. The `cleanup.sh` script automates the cleanup of S3 buckets, CloudWatch log groups, and performs the Terraform destroy operation.

6. **ZIP File Format**: Claims must be uploaded as ZIP files containing:
   - One PDF file (claim report)
   - One image file (PNG/JPG of damage)
   - Named as `claim-N.zip` (e.g., `claim-1.zip`)
   - The `stage3-test.sh` script automatically zips the claim documents from the data folder for you

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
- **Solution**: Bedrock models not enabled - see `code-talk/DEMO-SETUP.md` Step 3A to enable Claude Sonnet 4.6 (`global.anthropic.claude-sonnet-4-6`)
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
