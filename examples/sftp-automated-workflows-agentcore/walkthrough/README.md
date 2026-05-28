# Walkthrough — Staged Deployment

This folder is the educational, stage-by-stage path through the example. It exists alongside the one-shot deploy at the example root: both produce the same end-state, but the walkthrough lets you stop, inspect, and test each layer before moving to the next.

## When to use which

**One-shot deploy (recommended for first-time evaluation):**
```bash
cd ..
terraform init
terraform apply
```

The example root's `enable_*` flags default to `true`, so a single `terraform apply` provisions the full pipeline (foundation → transfer server → malware protection → AI orchestration → web app) in a single dependency-ordered run.

**Staged walkthrough (recommended for learning, demos, and workshops):**

Run the scripts in this folder in order. Each `stageN-deploy.sh` script applies an additive layer of resources by passing `-var-file=walkthrough/stageN.tfvars`, which selectively enables only the flags relevant to that stage.

## Prerequisites

See [`DEMO-SETUP.md`](./DEMO-SETUP.md) for the full prerequisites checklist:

- AWS CLI configured with admin credentials
- Terraform ≥ 1.5
- `jq`, `zip`, an SFTP client
- Bedrock Claude Sonnet 4.6 model access enabled in your account
- No existing IAM Identity Center instance (or adjust the configuration)

## Stages

All scripts live in `walkthrough/scripts/` and are invoked from there. Each `terraform` invocation runs against the example root (two levels up) via `terraform -chdir=../..`.

```bash
cd examples/sftp-automated-workflows-agentcore/walkthrough/scripts
```

### Stage 0 — Foundation

```bash
./stage0-deploy.sh    # IAM Identity Center, Cognito, S3 Access Grants,
                      # Custom IDP Lambda, 4 AgentCore agent runtimes
./stage0-verify.sh    # Verify environment + Bedrock model access
```

### Stage 1 — Transfer Server

```bash
./stage1-deploy.sh    # Transfer Family SFTP server + upload bucket
./stage1-test.sh      # Upload a test claim ZIP via SFTP
```

### Stage 2 — Malware Protection

```bash
./stage2-deploy.sh    # GuardDuty Malware Protection + clean/quarantine routing
./stage2-test.sh      # Upload clean and EICAR test files; observe routing
```

### Stage 3 — AI Claims Orchestration

```bash
./stage3-deploy.sh    # MCP gateway + claims_reader Lambda + DynamoDB +
                      # claims orchestrator Lambda
./stage3-test.sh      # End-to-end claim through all 4 AgentCore agents
```

### Stage 4 — Web App for Internal Users

```bash
./stage4-deploy.sh    # Transfer Family Web App + S3 Access Grants
```

## Demo helpers

Three additional scripts support live demo flows:

```bash
./run_demo.sh             # Starter narration for a presented demo
./monitor_agents.sh all   # Tail all agent + orchestrator logs (color-coded)
./view_results.sh         # List processed claims + open summary.html
```

## Cleanup

```bash
./cleanup.sh                     # Full cleanup (destroy + bucket emptying)
./cleanup.sh --reset-to-stage0   # Roll back to stage 0 only
```

## See also

- [`DEMO-SETUP.md`](./DEMO-SETUP.md) — detailed setup and troubleshooting
- [`../README.md`](../README.md) — the example overview and one-shot deploy reference
