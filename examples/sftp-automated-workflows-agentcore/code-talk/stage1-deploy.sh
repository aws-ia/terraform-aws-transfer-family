#!/bin/bash

################################################################################
# Stage 1 Deployment Script
# Deploys Transfer Family Server with Custom IDP and Cognito authentication
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Stage 1: Transfer Server Deployment${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Initialize Terraform if needed
if [ ! -d "$SCRIPT_DIR/.terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform -chdir="$SCRIPT_DIR" init -compact-warnings
    echo ""
fi

# Deploy Stage 1
echo -e "${YELLOW}Ready to deploy Stage 1 infrastructure${NC}"
echo ""
echo -e "${BLUE}Command:${NC} terraform apply -var-file=stage1.tfvars -auto-approve -compact-warnings"
echo ""
echo -e "${YELLOW}Press Enter to deploy...${NC}"
read -r

echo ""
echo -e "${YELLOW}Deploying Stage 1 infrastructure...${NC}"
terraform -chdir="$SCRIPT_DIR" apply -var-file="stage1.tfvars" -auto-approve -compact-warnings

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
    
    COGNITO_USER_POOL_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_user_pool_id 2>/dev/null || echo "")
    COGNITO_USERNAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_username 2>/dev/null || echo "")
    TRANSFER_SERVER_ENDPOINT=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_server_endpoint 2>/dev/null || echo "")
    TRANSFER_S3_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_s3_bucket_name 2>/dev/null || echo "")
    CLOUDFRONT_URL=$(terraform -chdir="$SCRIPT_DIR" output -raw cloudfront_url 2>/dev/null || echo "")
    
    # Display connection information
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Connection Information${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -n "$COGNITO_USER_POOL_ID" ]; then
        echo -e "${BLUE}Cognito User Pool ID:${NC}"
        echo "  $COGNITO_USER_POOL_ID"
        echo ""
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
    
    if [ -n "$TRANSFER_SERVER_ENDPOINT" ]; then
        echo -e "${BLUE}Transfer Server Endpoint:${NC}"
        echo "  $TRANSFER_SERVER_ENDPOINT"
        echo ""
    fi
    
    if [ -n "$TRANSFER_S3_BUCKET" ]; then
        echo -e "${BLUE}S3 Bucket:${NC}"
        echo "  $TRANSFER_S3_BUCKET"
        echo ""
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
else
    echo ""
    echo -e "${RED}=================================${NC}"
    echo -e "${RED}Deployment Failed!${NC}"
    echo -e "${RED}=================================${NC}"
    exit 1
fi
