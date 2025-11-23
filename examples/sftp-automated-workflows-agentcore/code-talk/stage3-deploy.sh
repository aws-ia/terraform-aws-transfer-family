#!/bin/bash

################################################################################
# Stage 3 Deployment Script
# Deploys AI Claims Processing with Amazon Bedrock
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
echo -e "${BLUE}Stage 3: AI Claims Processing Deployment${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Initialize Terraform if needed
if [ ! -d "$SCRIPT_DIR/.terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform -chdir="$SCRIPT_DIR" init -compact-warnings
    echo ""
fi

# Deploy Stage 3
echo -e "${YELLOW}Ready to deploy Stage 3 infrastructure${NC}"
echo ""
echo -e "${BLUE}Command:${NC} terraform apply -var-file=stage3.tfvars -auto-approve -compact-warnings"
echo ""
echo -e "${YELLOW}Press Enter to deploy...${NC}"
read -r

echo ""
echo -e "${YELLOW}Deploying Stage 3 infrastructure...${NC}"
terraform -chdir="$SCRIPT_DIR" apply -var-file="stage3.tfvars" -auto-approve -compact-warnings

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
    
    WORKFLOW_AGENT_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_workflow_agent_runtime_id 2>/dev/null || echo "")
    CLAIMS_TABLE=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_claims_table_name 2>/dev/null || echo "")
    CLEAN_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_clean_bucket_name 2>/dev/null || echo "")
    TRANSFER_SERVER_ENDPOINT=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_server_endpoint 2>/dev/null || echo "")
    
    # Display connection information
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}AI Claims Processing Information${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ -n "$TRANSFER_SERVER_ENDPOINT" ]; then
        echo -e "${BLUE}Transfer Server Endpoint:${NC}"
        echo "  $TRANSFER_SERVER_ENDPOINT"
        echo ""
    fi
    
    if [ -n "$WORKFLOW_AGENT_ID" ]; then
        echo -e "${BLUE}Workflow Agent Runtime ID:${NC}"
        echo "  $WORKFLOW_AGENT_ID"
        echo ""
    fi
    
    if [ -n "$CLAIMS_TABLE" ]; then
        echo -e "${BLUE}Claims DynamoDB Table:${NC}"
        echo "  $CLAIMS_TABLE"
        echo ""
    fi
    
    if [ -n "$CLEAN_BUCKET" ]; then
        echo -e "${BLUE}Clean Files S3 Bucket:${NC}"
        echo "  $CLEAN_BUCKET"
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
