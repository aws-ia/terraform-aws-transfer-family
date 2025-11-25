# AgentCore Refactoring Summary

## Overview
Separated ECR repository creation and Docker image builds (Stage 0) from Bedrock agent deployment (Stage 3) to optimize deployment time.

## Changes Made

### 1. New File: `stage0-agentcore-ecr.tf`
- Contains all 5 ECR repository definitions
- Contains all 5 Docker image build null_resources
- Controlled by `enable_agentcore_ecr` variable
- Builds Docker images once during Stage 0 (~2 minutes)

### 2. Updated File: `stage3-agentcore.tf`
- Added data sources to reference ECR repositories from Stage 0
- Passes ECR repository URLs to agentcore module
- Sets `skip_ecr_and_docker = true` flag

### 3. Updated File: `variables.tf`
- Added `enable_agentcore_ecr` variable (boolean)
- Placed between `enable_malware_protection` and `enable_agentcore`

### 4. Updated File: `stage0.tfvars`
- Set `enable_agentcore_ecr = true`
- Updated comments to reflect ECR/Docker builds

### 5. Updated File: `stage3.tfvars`
- Set `enable_agentcore_ecr = true` (keeps ECR repos alive)
- Updated comments to clarify agent deployment only

### 6. Updated Module: `modules/agentcore/variables.tf`
- Added `skip_ecr_and_docker` variable (boolean, default false)
- Added 5 ECR URL variables for passing repository URLs

### 7. Updated Module: `modules/agentcore/main.tf`
- Added locals block with conditional ECR URL logic
- Added `count` to all ECR repository resources
- Added `count` to all Docker build null_resources
- ECR repos and Docker builds only created when `skip_ecr_and_docker = false`

### 8. Updated Module: `modules/agentcore/agentcore.tf`
- Replaced direct ECR repository URL references with local variables
- Now uses `local.workflow_agent_url`, `local.entity_extraction_agent_url`, etc.

### 9. Updated File: `README.md`
- Updated Stage 0 description to include ECR/Docker builds
- Updated Stage 3 description to clarify agent deployment only

## Benefits

1. **Faster Stage 3 Deployments**: Saves ~2 minutes by skipping Docker builds
2. **Consistent Pattern**: Maintains stage file structure (no module toggling)
3. **Backward Compatible**: Module still works standalone with `skip_ecr_and_docker = false`
4. **Clear Separation**: ECR/Docker in Stage 0, Agent deployment in Stage 3

## Deployment Flow

### Stage 0
```bash
terraform apply -var-file=stage0.tfvars
```
- Creates ECR repositories
- Builds and pushes 5 Docker images (~2 min)
- Creates identity infrastructure

### Stage 3
```bash
terraform apply -var-file=stage3.tfvars
```
- References existing ECR repositories via data sources
- Deploys 5 Bedrock agents using pre-built images
- No Docker builds = faster deployment

## Important Notes

1. **Both tfvars need `enable_agentcore_ecr = true`**: This prevents ECR destruction when moving between stages
2. **Docker images persist**: Null_resource triggers prevent rebuilds when images exist
3. **Module flexibility**: Can still be used standalone by setting `skip_ecr_and_docker = false`
