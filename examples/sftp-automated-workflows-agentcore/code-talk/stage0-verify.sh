#!/bin/bash

################################################################################
# Stage 0 Verification Script
# Verifies the environment is set up correctly for the demo
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Stage 0: Environment Verification${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Track overall status
ALL_CHECKS_PASSED=true

# Function to print check result
check_result() {
    local status=$1
    local message=$2
    
    if [ "$status" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "fail" ]; then
        echo -e "${RED}✗${NC} $message"
        ALL_CHECKS_PASSED=false
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${BLUE}ℹ${NC} $message"
    fi
}

echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

# Check AWS CLI
if command -v aws &> /dev/null; then
    check_result "pass" "AWS CLI installed"
else
    check_result "fail" "AWS CLI not found"
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform --version | head -n1)
    check_result "pass" "Terraform installed ($TF_VERSION)"
else
    check_result "fail" "Terraform not found"
fi

# Check jq
if command -v jq &> /dev/null; then
    check_result "pass" "jq installed"
else
    check_result "fail" "jq not found (required for JSON parsing)"
fi

# Check SFTP
if command -v sftp &> /dev/null; then
    check_result "pass" "SFTP client available"
else
    check_result "fail" "SFTP client not found"
fi

# Check clipboard utility
if command -v pbcopy &> /dev/null; then
    check_result "pass" "Clipboard utility available (pbcopy)"
elif command -v xclip &> /dev/null; then
    check_result "pass" "Clipboard utility available (xclip)"
elif command -v xsel &> /dev/null; then
    check_result "pass" "Clipboard utility available (xsel)"
elif command -v clip.exe &> /dev/null; then
    check_result "pass" "Clipboard utility available (clip.exe)"
else
    check_result "warn" "No clipboard utility found (optional)"
fi

echo ""
echo -e "${YELLOW}Checking AWS credentials...${NC}"
echo ""

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    check_result "pass" "AWS credentials configured"
    echo -e "  ${BLUE}Account:${NC} $AWS_ACCOUNT"
    echo -e "  ${BLUE}Identity:${NC} $AWS_USER"
else
    check_result "fail" "AWS credentials not configured or invalid"
fi

echo ""
echo -e "${YELLOW}Checking Terraform state...${NC}"
echo ""

# Check if Terraform state exists
if [ ! -f "$SCRIPT_DIR/terraform.tfstate" ]; then
    check_result "fail" "Terraform state not found - run ./stage0-deploy.sh first"
    echo ""
    echo -e "${RED}Cannot continue verification without deployed infrastructure.${NC}"
    exit 1
fi

check_result "pass" "Terraform state found"

echo ""
echo -e "${YELLOW}Checking deployed resources...${NC}"
echo ""

# Check Identity Center
IDENTITY_CENTER_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw identity_center_instance_arn 2>/dev/null || echo "")
if [ -n "$IDENTITY_CENTER_ARN" ]; then
    check_result "pass" "IAM Identity Center deployed"
else
    check_result "fail" "IAM Identity Center not found"
fi

# Check Identity Store
IDENTITY_STORE_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw identity_store_id 2>/dev/null || echo "")
if [ -n "$IDENTITY_STORE_ID" ]; then
    check_result "pass" "Identity Store configured"
else
    check_result "fail" "Identity Store not found"
fi

# Check S3 Access Grants
S3_ACCESS_GRANTS_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw s3_access_grants_instance_arn 2>/dev/null || echo "")
if [ -n "$S3_ACCESS_GRANTS_ARN" ]; then
    check_result "pass" "S3 Access Grants instance created"
else
    check_result "fail" "S3 Access Grants instance not found"
fi

# Check Cognito User Pool
COGNITO_USER_POOL_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_user_pool_id 2>/dev/null || echo "")
if [ -n "$COGNITO_USER_POOL_ID" ]; then
    check_result "pass" "Cognito User Pool created"
    
    # Check if Cognito user exists
    COGNITO_USERNAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_username 2>/dev/null || echo "")
    if [ -n "$COGNITO_USERNAME" ]; then
        USER_STATUS=$(aws cognito-idp admin-get-user --user-pool-id "$COGNITO_USER_POOL_ID" --username "$COGNITO_USERNAME" --query UserStatus --output text 2>/dev/null || echo "")
        if [ -n "$USER_STATUS" ]; then
            check_result "pass" "Cognito user exists (Status: $USER_STATUS)"
        else
            check_result "fail" "Cognito user not found"
        fi
    fi
else
    check_result "fail" "Cognito User Pool not found"
fi

# Check Cognito password in Secrets Manager
COGNITO_PASSWORD_SECRET_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_password_secret_arn 2>/dev/null || echo "")
if [ -n "$COGNITO_PASSWORD_SECRET_ARN" ]; then
    PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$COGNITO_PASSWORD_SECRET_ARN" --query SecretString --output text 2>/dev/null | jq -r .password 2>/dev/null || echo "")
    if [ -n "$PASSWORD" ]; then
        check_result "pass" "Cognito password stored in Secrets Manager"
    else
        check_result "fail" "Cannot retrieve Cognito password"
    fi
else
    check_result "fail" "Cognito password secret not found"
fi

echo ""
echo -e "${YELLOW}Checking Amazon Bedrock access...${NC}"
echo ""

# Check Bedrock model access
AWS_REGION=$(aws configure get region || echo "us-east-1")

# Required models for agentcore
REQUIRED_HAIKU="anthropic.claude-3-haiku-20240307-v1:0"
REQUIRED_SONNET="anthropic.claude-3-5-sonnet-20240620-v1:0"

# Check Claude 3 Haiku
HAIKU_STATUS=$(aws bedrock list-foundation-models --region "$AWS_REGION" --query "modelSummaries[?modelId=='$REQUIRED_HAIKU'].modelId" --output text 2>/dev/null || echo "")
if [ -n "$HAIKU_STATUS" ]; then
    check_result "pass" "Claude 3 Haiku model accessible"
    
    # Test model invocation
    TEST_RESPONSE=$(aws bedrock-runtime invoke-model \
        --region "$AWS_REGION" \
        --model-id "$REQUIRED_HAIKU" \
        --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}' \
        --cli-binary-format raw-in-base64-out \
        /dev/stdout 2>/dev/null | jq -r '.content[0].text' 2>/dev/null || echo "")
    
    if [ -n "$TEST_RESPONSE" ]; then
        check_result "pass" "Claude 3 Haiku invocation successful"
    else
        check_result "fail" "Claude 3 Haiku invocation failed - check model access permissions"
    fi
else
    check_result "fail" "Claude 3 Haiku not accessible - enable in Bedrock console"
fi

# Check Claude 3.5 Sonnet
SONNET_STATUS=$(aws bedrock list-foundation-models --region "$AWS_REGION" --query "modelSummaries[?modelId=='$REQUIRED_SONNET'].modelId" --output text 2>/dev/null || echo "")
if [ -n "$SONNET_STATUS" ]; then
    check_result "pass" "Claude 3.5 Sonnet model accessible"
    
    # Test model invocation
    TEST_RESPONSE=$(aws bedrock-runtime invoke-model \
        --region "$AWS_REGION" \
        --model-id "$REQUIRED_SONNET" \
        --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}' \
        --cli-binary-format raw-in-base64-out \
        /dev/stdout 2>/dev/null | jq -r '.content[0].text' 2>/dev/null || echo "")
    
    if [ -n "$TEST_RESPONSE" ]; then
        check_result "pass" "Claude 3.5 Sonnet invocation successful"
    else
        check_result "fail" "Claude 3.5 Sonnet invocation failed - check model access permissions"
    fi
else
    check_result "fail" "Claude 3.5 Sonnet not accessible - enable in Bedrock console"
fi

echo ""
echo -e "${YELLOW}Manual configuration checks...${NC}"
echo ""

check_result "info" "The following must be verified manually:"
echo ""
echo -e "  ${YELLOW}1.${NC} IAM Identity Center MFA disabled for demo users"
echo -e "     ${BLUE}→${NC} https://console.aws.amazon.com/singlesignon/home?region=$AWS_REGION#/settings/authentication"
echo ""
echo -e "  ${YELLOW}2.${NC} Claims Reviewer password reset"
echo -e "     ${BLUE}→${NC} https://console.aws.amazon.com/singlesignon/home?region=$AWS_REGION#/users"
echo ""
echo -e "  ${YELLOW}3.${NC} Claims Administrator password reset"
echo -e "     ${BLUE}→${NC} https://console.aws.amazon.com/singlesignon/home?region=$AWS_REGION#/users"
echo ""
echo -e "  ${YELLOW}4.${NC} Bedrock model access enabled and use case form completed"
echo -e "     ${BLUE}→${NC} https://console.aws.amazon.com/bedrock/home?region=$AWS_REGION#/modelaccess"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Verification Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All automated checks passed!${NC}"
    echo ""
    echo -e "Complete the manual configuration steps above, then proceed to Stage 1:"
    echo -e "  ${GREEN}./stage1-deploy.sh${NC}"
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo ""
    echo -e "Please resolve the issues above before proceeding."
    echo -e "See ${BLUE}DEMO-SETUP.md${NC} for detailed setup instructions."
fi

echo ""
