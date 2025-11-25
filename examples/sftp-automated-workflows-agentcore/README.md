# Transfer Family POC - Incremental Demo

This project demonstrates AWS Transfer Family with incremental stages, allowing you to build up the solution progressively.

## Architecture Overview

The solution consists of 5 stages that build upon each other:

### Stage 0: Identity Foundation + AgentCore ECR
**"Setting up identity and access infrastructure + Docker images"**
- IAM Identity Center with users and groups
- S3 Access Grants instance
- Cognito user pool for external authentication
- ECR repositories and Docker images for AgentCore agents (~2 min build time)

**Demo**: Show foundational identity infrastructure and pre-built agent images

### Stage 1: Transfer Server with External Users
**"Secure file transfer with custom authentication"**
- Transfer Family SFTP server
- Custom Identity Provider (Lambda-based)
- S3 bucket for file storage
- External user (anycompany-repairs) authentication via Cognito

**Demo**: External user can SFTP to their folder

### Stage 2: Malware Protection
**"Automated malware scanning on upload"**
- GuardDuty Malware Protection
- Automatic scanning of uploaded files
- Clean and quarantine buckets

**Demo**: Upload file via SFTP → GuardDuty scans → moves to clean/quarantine bucket

### Stage 3: AI Claims Processing
**"Intelligent claims processing with Bedrock"**
- Agentcore with Amazon Bedrock (agent deployment only)
- Automated claims data extraction
- Fraud detection
- DynamoDB storage
- Uses pre-built Docker images from Stage 0

**Demo**: Upload claim PDF → Malware scan → AI extracts data → Fraud detection → Database insert

### Stage 4: Web Access for Internal Users
**"Complete solution with web-based file access"**
- Transfer Family Web App
- S3 Access Grants for fine-grained permissions
- Internal users (claims.reviewer, claims.administrator)
- Shared documents bucket

**Demo**: Internal users access files via web UI with fine-grained permissions

## Usage

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured
- Appropriate AWS permissions

### Deploy a Stage

```bash
# Initialize Terraform (first time only)
terraform init

# Stage 0: Identity Foundation
terraform plan -var-file=stage0.tfvars
terraform apply -var-file=stage0.tfvars

# Stage 1: Add Transfer Server
terraform plan -var-file=stage1.tfvars
terraform apply -var-file=stage1.tfvars

# Stage 2: Add Malware Protection
terraform plan -var-file=stage2.tfvars
terraform apply -var-file=stage2.tfvars

# Stage 3: Add AI Claims Processing
terraform plan -var-file=stage3.tfvars
terraform apply -var-file=stage3.tfvars

# Stage 4: Add Web Application
terraform plan -var-file=stage4.tfvars
terraform apply -var-file=stage4.tfvars
```

### Destroy Resources

```bash
# Destroy specific stage
terraform destroy -var-file=stage4.tfvars

# Or destroy all
terraform destroy
```

## Project Structure

```
.
├── main.tf                          # Minimal main config
├── variables.tf                     # Feature flag variables
├── outputs.tf                       # Conditional outputs
├── providers.tf                     # AWS provider configuration
├── stage0-foundation.tf             # Identity Center, S3 Access Grants, Cognito
├── stage1-transfer-server.tf        # Transfer Server + Custom IDP
├── stage2-malware-protection.tf     # GuardDuty malware scanning
├── stage3-agentcore.tf              # AI claims processing
├── stage4-webapp.tf                 # Web application
├── stage0.tfvars                    # Stage 0 configuration
├── stage1.tfvars                    # Stage 1 configuration
├── stage2.tfvars                    # Stage 2 configuration
├── stage3.tfvars                    # Stage 3 configuration
├── stage4.tfvars                    # Stage 4 configuration
├── modules/                         # Reusable Terraform modules
│   ├── custom-idp-solution/
│   ├── cognito-hosted-ui/
│   ├── transfer-webapp/
│   ├── agentcore/
│   └── malware-protection/
└── target-state-build/              # Reference: Complete Stage 4 solution
```

## Feature Flags

The solution uses feature flags to enable/disable components:

- `enable_identity_center` - IAM Identity Center
- `enable_s3_access_grants` - S3 Access Grants
- `enable_cognito` - Cognito user pool
- `enable_custom_idp` - Custom Identity Provider
- `enable_transfer_server` - Transfer Family server
- `enable_malware_protection` - GuardDuty malware scanning
- `enable_agentcore` - AI claims processing
- `enable_webapp` - Web application

## Important Notes

1. **Stage Dependencies**: Each stage builds on the previous one. Don't skip stages.
2. **Identity Center**: Only one Identity Center instance per AWS account. If you already have one, adjust accordingly.
3. **S3 Access Grants**: Only one instance per AWS account.
4. **Costs**: Be aware of AWS service costs, especially for Transfer Family, GuardDuty, and Bedrock.
5. **Cleanup**: Always destroy resources when done to avoid unnecessary charges.

## Reference Implementation

The `target-state-build/` directory contains a complete, standalone implementation of Stage 4 (all components enabled). This serves as a reference and can be deployed independently:

```bash
cd target-state-build
terraform init
terraform apply
```

## Outputs

Each stage provides relevant outputs. Use `terraform output` to view them:

```bash
terraform output
```

Key outputs include:
- Transfer server endpoint
- Cognito user credentials (in Secrets Manager)
- Web app endpoint
- S3 bucket names
- Lambda function names
