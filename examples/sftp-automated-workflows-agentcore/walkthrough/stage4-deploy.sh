#!/bin/bash

################################################################################
# Stage 4 Deployment Script
# Deploys Transfer Family Web App with S3 Access Grants
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
echo -e "${BLUE}Stage 4: Web App Deployment${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Initialize Terraform if needed
if [ ! -d "$SCRIPT_DIR/.terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform -chdir="$SCRIPT_DIR" init -compact-warnings
    echo ""
fi

# Deploy Stage 4
echo -e "${YELLOW}Ready to deploy Stage 4 infrastructure${NC}"
echo ""
echo -e "${BLUE}Command:${NC} terraform apply -var-file=stage4.tfvars -auto-approve -compact-warnings"
echo ""
echo -e "${YELLOW}Press Enter to deploy...${NC}"
read -r

echo ""
echo -e "${YELLOW}Deploying Stage 4 infrastructure...${NC}"
terraform -chdir="$SCRIPT_DIR" apply -var-file="stage4.tfvars" -auto-approve -compact-warnings

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
    
    WEB_APP_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw web_app_arn 2>/dev/null || echo "")
    WEB_APP_ENDPOINT=$(terraform -chdir="$SCRIPT_DIR" output -raw web_app_endpoint 2>/dev/null || echo "")
    MALWARE_CLEAN_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_clean_bucket_name 2>/dev/null || echo "")
    IDENTITY_CENTER_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw identity_center_instance_arn 2>/dev/null || echo "")
    
    # Display connection information
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Web Application Information${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -n "$WEB_APP_ENDPOINT" ]; then
        echo -e "${BLUE}Web App Endpoint:${NC}"
        echo "  $WEB_APP_ENDPOINT"
        echo ""
    fi
    
    if [ -n "$WEB_APP_ARN" ]; then
        echo -e "${BLUE}Web App ARN:${NC}"
        echo "  $WEB_APP_ARN"
        echo ""
    fi
    
    if [ -n "$MALWARE_CLEAN_BUCKET" ]; then
        echo -e "${BLUE}Clean Files S3 Bucket:${NC}"
        echo "  $MALWARE_CLEAN_BUCKET"
        echo ""
    fi
    
    if [ -n "$IDENTITY_CENTER_ARN" ]; then
        echo -e "${BLUE}IAM Identity Center:${NC}"
        echo "  $IDENTITY_CENTER_ARN"
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
