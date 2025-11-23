#!/bin/bash

################################################################################
# Stage 0 Deployment Script
# Deploys Identity Foundation: IAM Identity Center, S3 Access Grants, Cognito
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (parent of code-talk folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Stage 0: Identity Foundation Deployment${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Initialize Terraform if needed
if [ ! -d "$SCRIPT_DIR/.terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform -chdir="$SCRIPT_DIR" init -compact-warnings
    echo ""
fi

# Deploy Stage 0
echo -e "${YELLOW}Ready to deploy Stage 0 infrastructure${NC}"
echo ""
echo -e "${BLUE}Command:${NC} terraform apply -var-file=stage0.tfvars -auto-approve -compact-warnings"
echo ""
echo -e "${YELLOW}Press Enter to deploy...${NC}"
read -r

echo ""
echo -e "${YELLOW}Deploying Stage 0 infrastructure...${NC}"
terraform -chdir="$SCRIPT_DIR" apply -var-file="stage0.tfvars" -auto-approve -compact-warnings

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}Deployment Successful!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    
    # Extract outputs
    echo -e "${BLUE}Retrieving deployment information...${NC}"
    echo ""
    
    IDENTITY_CENTER_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw identity_center_instance_arn 2>/dev/null || echo "")
    IDENTITY_STORE_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw identity_store_id 2>/dev/null || echo "")
    S3_ACCESS_GRANTS_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw s3_access_grants_instance_arn 2>/dev/null || echo "")
    COGNITO_USER_POOL_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_user_pool_id 2>/dev/null || echo "")
    COGNITO_USERNAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_username 2>/dev/null || echo "")
    COGNITO_PASSWORD_SECRET_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_password_secret_arn 2>/dev/null || echo "")
    CLOUDFRONT_URL=$(terraform -chdir="$SCRIPT_DIR" output -raw cloudfront_url 2>/dev/null || echo "")
    
    # Get AWS region and account ID
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    
    # Display connection information
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Identity Foundation Information${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -n "$IDENTITY_CENTER_ARN" ]; then
        echo -e "${BLUE}IAM Identity Center ARN:${NC}"
        echo "  $IDENTITY_CENTER_ARN"
        echo ""
        if [ -n "$AWS_ACCOUNT_ID" ]; then
            echo -e "${BLUE}Console Link:${NC}"
            echo "  https://console.aws.amazon.com/singlesignon/home?region=$AWS_REGION#/"
            echo ""
        fi
    fi
    
    if [ -n "$IDENTITY_STORE_ID" ]; then
        echo -e "${BLUE}Identity Store ID:${NC}"
        echo "  $IDENTITY_STORE_ID"
        echo ""
    fi
    
    if [ -n "$S3_ACCESS_GRANTS_ARN" ]; then
        echo -e "${BLUE}S3 Access Grants ARN:${NC}"
        echo "  $S3_ACCESS_GRANTS_ARN"
        echo ""
    fi
    
    if [ -n "$COGNITO_USER_POOL_ID" ]; then
        echo -e "${BLUE}Cognito User Pool ID:${NC}"
        echo "  $COGNITO_USER_POOL_ID"
        echo ""
        if [ -n "$AWS_REGION" ]; then
            echo -e "${BLUE}Console Link:${NC}"
            echo "  https://console.aws.amazon.com/cognito/v2/idp/user-pools/$COGNITO_USER_POOL_ID/users?region=$AWS_REGION"
            echo ""
        fi
    fi
    
    if [ -n "$COGNITO_USERNAME" ]; then
        echo -e "${BLUE}Cognito Username:${NC}"
        echo "  $COGNITO_USERNAME"
        echo ""
    fi
    
    if [ -n "$CLOUDFRONT_URL" ]; then
        echo -e "${BLUE}Cognito Hosted UI:${NC}"
        echo "  $CLOUDFRONT_URL"
        echo ""
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${YELLOW}⚠️  IMPORTANT: Manual configuration required!${NC}"
    echo ""
    echo -e "Run the verification script to check your setup:"
    echo -e "  ${GREEN}./stage0-verify.sh${NC}"
    echo ""
    echo -e "See ${BLUE}DEMO-SETUP.md${NC} for manual configuration steps."
    echo ""
    
else
    echo ""
    echo -e "${RED}=================================${NC}"
    echo -e "${RED}Deployment Failed!${NC}"
    echo -e "${RED}=================================${NC}"
    exit 1
fi
