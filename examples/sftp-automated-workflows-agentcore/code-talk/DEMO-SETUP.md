# Demo Setup Guide - Stage 0 & Stage 1

This guide walks through the setup process for the SFTP Automated Workflows demo, covering the identity foundation and transfer server deployment.

## Prerequisites

### Required Tools

- [ ] **AWS Account Access**: Administrator access to an AWS account
- [ ] **AWS CLI Configured**: Run `aws configure` and verify with `aws sts get-caller-identity`
- [ ] **Terraform**: Version 1.0 or later (`terraform --version`)
- [ ] **jq**: For JSON parsing (`jq --version`)
- [ ] **SFTP Client**: Verify `sftp` command is available

### Optional Tools

- [ ] **Clipboard Utility** (recommended for easier password handling):
  - macOS: `pbcopy` (built-in)
  - Linux: `xclip` or `xsel` (`sudo apt-get install xclip`)
  - WSL: `clip.exe` (built-in)

## Stage 0: Identity Foundation

Stage 0 deploys the identity and authentication infrastructure:
- IAM Identity Center for internal users
- S3 Access Grants for fine-grained permissions
- Cognito User Pool for external users (SFTP)

### Step 1: Deploy Infrastructure

```bash
cd examples/sftp-automated-workflows-agentcore/code-talk
./stage0-deploy.sh
```

The script will:
1. Initialize Terraform
2. Show the deployment command
3. Wait for confirmation
4. Deploy all Stage 0 resources
5. Display deployment information with console links

### Step 2: Verify Deployment

Run the verification script to check your environment (from the code-talk folder):

```bash
./stage0-verify.sh
```

This will check:
- ✓ Prerequisites (AWS CLI, Terraform, jq, SFTP)
- ✓ AWS credentials
- ✓ Deployed resources (Identity Center, Cognito, S3 Access Grants)
- ✓ Bedrock model access

### Step 3: Manual Configuration

The following steps may need to be completed manually in the AWS Console. **Check the verification script output first** - if all checks passed, you can skip to Step 4.

#### A. Enable Bedrock Models (If Verification Failed)

**Only complete this section if the verification script showed failed Bedrock model checks.**

1. **Open Bedrock Console**:
   - Navigate to: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess
   - Or: AWS Console → Amazon Bedrock → Model access

2. **Enable Required Claude Models**:
   - Click "Manage model access"
   - Enable these specific models:
     - ✓ **Anthropic Claude 3 Haiku** (required for entity extraction, database, summary agents)
     - ✓ **Anthropic Claude 3.5 Sonnet** (required for fraud validation with vision)
   - Click "Save changes"

3. **Complete Use Case Form** (if prompted):
   - Fill out the required information
   - Submit the form
   - Wait for approval (usually instant)

4. **Re-run Verification**:
   ```bash
   ./stage0-verify.sh
   ```
   - Bedrock checks should now pass
   - Model invocation tests should succeed

#### B. Configure IAM Identity Center (Required)

1. **Open Identity Center Console**:
   - Navigate to: https://console.aws.amazon.com/singlesignon/home
   - Or: AWS Console → IAM Identity Center

2. **Disable MFA** (Required for demo):
   - Go to: Settings → Authentication
   - Click "Configure" under Multi-factor authentication
   - Select "Every time they sign in (always-on)"
   - Set to "Optional" or uncheck "Require MFA"
   - Click "Save changes"
   - **Why**: Simplifies demo flow; re-enable after demo

3. **Reset User Passwords**:
   
   **For Claims Reviewer**:
   - Go to: Users (left sidebar)
   - Find and click "claims-reviewer"
   - Click "Reset password"
   - Choose "Send an email to the user with instructions"
   - **Note**: Save the password for Stage 4 demo
   
   **For Claims Administrator**:
   - Repeat the same process for "claims-administrator"
   - **Note**: Save the password for Stage 4 demo

### Step 4: Verify Stage 0 Complete

Run the verification script again to confirm everything is ready:

```bash
./stage0-verify.sh
```

All automated checks should pass. Manual configuration items are listed for your reference.

---

## Environment Ready!

Your demo environment is now configured and ready to use. You can deploy and test each stage in order:

### Available Stages

**Stage 1: Transfer Server**
```bash
./stage1-deploy.sh  # Deploy SFTP server
./stage1-test.sh    # Test SFTP upload
```

**Stage 2: Malware Protection**
```bash
./stage2-deploy.sh  # Deploy GuardDuty malware scanning
./stage2-test.sh    # Test malware scan and routing
```

**Stage 3: AI Claims Processing**
```bash
./stage3-deploy.sh  # Deploy Bedrock agents
./stage3-test.sh    # Test AI processing pipeline
```

**Stage 4: Web Application**
```bash
./stage4-deploy.sh  # Deploy web app for internal users
```

Each deployment script will:
- Show the terraform command
- Wait for your confirmation
- Deploy the infrastructure
- Display relevant outputs and console links

Each test script will:
- Retrieve necessary credentials
- Execute the workflow for that stage
- Display results and verification steps
- Clean up test data

---

## Troubleshooting

### Common Issues

**Issue**: `./stage0-deploy.sh: command not found`
- **Solution**: Make sure you're in the correct directory: `cd examples/sftp-automated-workflows-agentcore`
- **Solution**: Ensure script is executable: `chmod +x stage0-deploy.sh`

**Issue**: Terraform fails with "Identity Center instance already exists"
- **Solution**: An Identity Center instance already exists in your account (only one allowed per account)
- **Solution**: Either use the existing instance or delete it first

**Issue**: Bedrock model access denied
- **Solution**: Complete Step 3A above to enable Claude models
- **Solution**: Ensure use case form is submitted and approved

**Issue**: SFTP connection fails
- **Solution**: Wait a few minutes for Transfer Server to become active
- **Solution**: Verify server status: `aws transfer describe-server --server-id $(terraform output -raw transfer_server_id)`

**Issue**: Password not in clipboard
- **Solution**: Install clipboard utility (see Prerequisites)
- **Solution**: Manually copy password from script output

**Issue**: MFA prompts during Identity Center login
- **Solution**: Complete Step 3B above to disable MFA

**Issue**: Verification script shows failures
- **Solution**: Review the specific check that failed
- **Solution**: Ensure all manual configuration steps are complete
- **Solution**: Check AWS credentials and permissions

---

## Next Steps

After completing Stage 0 and Stage 1:

- **Stage 2**: Malware Protection - Run `./stage2-deploy.sh` (see separate documentation)
- **Stage 3**: AI Claims Processing - Run `./stage3-deploy.sh` (see separate documentation)
- **Stage 4**: Web Application - Run `./stage4-deploy.sh` (see separate documentation)

---

## Cleanup

When finished with the demo, you have two cleanup options (from the code-talk folder):

### Option 1: Full Cleanup (Destroy Everything)

```bash
./cleanup.sh
```

This will:
1. Empty all S3 buckets
2. Destroy all infrastructure (Stages 0-4)
3. Remove local Terraform state files

### Option 2: Reset to Stage 0 (Keep Identity Foundation)

```bash
./cleanup.sh --reset-to-stage0
```

This will:
1. Empty all S3 buckets
2. Destroy Stages 1-4 only
3. Preserve Stage 0 (Identity Center, Cognito, S3 Access Grants)
4. Keep Terraform state for Stage 0

**Use this option when**:
- You want to re-run the demo from Stage 1
- You want to avoid reconfiguring Identity Center and Bedrock
- You're iterating on Stages 1-4 configurations

---

## Quick Reference

### Useful Commands

```bash
# View all Terraform outputs
terraform output

# Get specific output
terraform output -raw transfer_server_endpoint

# Check AWS account
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# View Cognito users
aws cognito-idp list-users --user-pool-id $(terraform output -raw cognito_user_pool_id)
```

### Console Links

- **IAM Identity Center**: https://console.aws.amazon.com/singlesignon/home
- **Amazon Bedrock**: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess
- **Amazon Cognito**: https://console.aws.amazon.com/cognito/v2/home
- **AWS Transfer Family**: https://console.aws.amazon.com/transfer/home
- **Amazon S3**: https://console.aws.amazon.com/s3/home

### Additional Resources

- [Transfer Family Documentation](https://docs.aws.amazon.com/transfer/)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/)
- [Amazon Cognito Documentation](https://docs.aws.amazon.com/cognito/)
