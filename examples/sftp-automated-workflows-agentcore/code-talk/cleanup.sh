#!/bin/bash

################################################################################
# Cleanup Script
# Removes all objects from S3 buckets and destroys infrastructure
# Usage: ./cleanup.sh [--reset-to-stage0]
################################################################################

set -e  # Exit on error

# Disable AWS CLI pager
export AWS_PAGER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (parent of code-talk folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Check for reset flag
RESET_TO_STAGE0=false
if [ "$1" = "--reset-to-stage0" ]; then
    RESET_TO_STAGE0=true
fi

echo -e "${RED}=================================${NC}"
echo -e "${RED}Infrastructure Cleanup${NC}"
echo -e "${RED}=================================${NC}"
echo ""

if [ "$RESET_TO_STAGE0" = true ]; then
    echo -e "${YELLOW}Mode: Reset to Stage 0 (keep identity foundation)${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will destroy Stages 1-4 and delete all data!${NC}"
    echo -e "${YELLOW}Stage 0 (Identity Center, Cognito, S3 Access Grants) will be preserved.${NC}"
else
    echo -e "${YELLOW}Mode: Full cleanup (destroy all infrastructure)${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will destroy all infrastructure and delete all data!${NC}"
fi

echo ""
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read -r

echo ""

# Check if Terraform state exists
if [ ! -f "$SCRIPT_DIR/terraform.tfstate" ]; then
    echo -e "${YELLOW}No Terraform state found. Nothing to clean up.${NC}"
    exit 0
fi

# Extract bucket names from Terraform state
echo -e "${BLUE}Retrieving S3 bucket names...${NC}"
echo ""

TRANSFER_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_s3_bucket_name 2>/dev/null || echo "")
UPLOAD_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_upload_bucket_name 2>/dev/null || echo "")
CLEAN_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_clean_bucket_name 2>/dev/null || echo "")
QUARANTINE_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_quarantine_bucket_name 2>/dev/null || echo "")
ERRORS_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_errors_bucket_name 2>/dev/null || echo "")

# Function to empty S3 bucket
empty_bucket() {
    local bucket=$1
    local bucket_name=$2
    
    if [ -n "$bucket" ]; then
        echo -e "${YELLOW}Emptying $bucket_name...${NC}"
        
        # Check if bucket exists
        if aws s3 ls "s3://$bucket" 2>/dev/null; then
            # Delete all objects and versions
            aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
            
            # Delete all object versions (for versioned buckets)
            echo "  Deleting object versions..."
            aws s3api list-object-versions --bucket "$bucket" --output json --no-cli-pager 2>/dev/null | \
                jq -r '.Versions[]? | "--key \(.Key) --version-id \(.VersionId)"' 2>/dev/null | \
                while IFS= read -r args; do
                    if [ -n "$args" ]; then
                        eval "aws s3api delete-object --bucket \"$bucket\" $args --no-cli-pager" 2>/dev/null || true
                    fi
                done
            
            # Delete all delete markers
            echo "  Deleting delete markers..."
            aws s3api list-object-versions --bucket "$bucket" --output json --no-cli-pager 2>/dev/null | \
                jq -r '.DeleteMarkers[]? | "--key \(.Key) --version-id \(.VersionId)"' 2>/dev/null | \
                while IFS= read -r args; do
                    if [ -n "$args" ]; then
                        eval "aws s3api delete-object --bucket \"$bucket\" $args --no-cli-pager" 2>/dev/null || true
                    fi
                done
            
            echo -e "${GREEN}✓ $bucket_name emptied${NC}"
        else
            echo -e "${YELLOW}⚠ $bucket_name does not exist or is already deleted${NC}"
        fi
    fi
}

# Empty all S3 buckets
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Cleaning S3 Buckets${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

empty_bucket "$TRANSFER_BUCKET" "Transfer Bucket"
empty_bucket "$UPLOAD_BUCKET" "Upload Bucket"
empty_bucket "$CLEAN_BUCKET" "Clean Bucket"
empty_bucket "$QUARANTINE_BUCKET" "Quarantine Bucket"
empty_bucket "$ERRORS_BUCKET" "Errors Bucket"

echo ""
echo -e "${GREEN}✓ All S3 buckets cleaned${NC}"
echo ""

# Clean up CloudWatch Log Groups
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Cleaning CloudWatch Log Groups${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Deleting agent log groups...${NC}"

# Find and delete all agentcore runtime log groups
LOG_GROUPS=$(aws logs describe-log-groups \
    --log-group-name-prefix "/aws/bedrock-agentcore/runtimes/" \
    --query 'logGroups[].logGroupName' \
    --output text 2>/dev/null || echo "")

if [ -n "$LOG_GROUPS" ]; then
    LOG_GROUP_COUNT=$(echo "$LOG_GROUPS" | wc -w)
    echo "  Found $LOG_GROUP_COUNT agent log groups"
    
    for LOG_GROUP in $LOG_GROUPS; do
        echo "  Deleting $LOG_GROUP..."
        aws logs delete-log-group --log-group-name "$LOG_GROUP" 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ Agent log groups deleted${NC}"
else
    echo -e "${YELLOW}⚠ No agent log groups found${NC}"
fi

echo ""

# Destroy infrastructure
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Destroying Infrastructure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$RESET_TO_STAGE0" = true ]; then
    echo -e "${YELLOW}Resetting to Stage 0...${NC}"
    echo ""
    echo -e "${BLUE}Command:${NC} terraform apply -var-file=stage0.tfvars -auto-approve -compact-warnings"
    echo ""
    echo -e "${YELLOW}Press Enter to reset to Stage 0...${NC}"
    read -r
    
    terraform -chdir="$SCRIPT_DIR" apply -var-file="stage0.tfvars" -auto-approve -compact-warnings
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}=================================${NC}"
        echo -e "${GREEN}Reset to Stage 0 Successful!${NC}"
        echo -e "${GREEN}=================================${NC}"
        echo ""
        echo -e "${GREEN}Stages 1-4 have been destroyed.${NC}"
        echo -e "${GREEN}Stage 0 (Identity foundation) is preserved.${NC}"
        echo ""
        echo -e "${BLUE}You can now deploy Stage 1 again:${NC}"
        echo -e "  ${GREEN}./stage1-deploy.sh${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}=================================${NC}"
        echo -e "${RED}Reset Failed!${NC}"
        echo -e "${RED}=================================${NC}"
        echo ""
        echo -e "${RED}Some resources may not have been reset properly.${NC}"
        echo -e "${YELLOW}Please check the AWS Console and manually verify resources.${NC}"
        echo ""
        exit 1
    fi
else
    echo -e "${YELLOW}Running terraform destroy...${NC}"
    echo ""
    echo -e "${BLUE}Command:${NC} terraform destroy -auto-approve -compact-warnings"
    echo ""
    echo -e "${YELLOW}Press Enter to destroy all infrastructure...${NC}"
    read -r
    
    terraform -chdir="$SCRIPT_DIR" destroy -auto-approve -compact-warnings
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}=================================${NC}"
        echo -e "${GREEN}Cleanup Successful!${NC}"
        echo -e "${GREEN}=================================${NC}"
        echo ""
        echo -e "${GREEN}All resources have been destroyed.${NC}"
        echo ""
        
        # Clean up local state files
        echo -e "${YELLOW}Cleaning up local Terraform files...${NC}"
        rm -f "$SCRIPT_DIR/terraform.tfstate"
        rm -f "$SCRIPT_DIR/terraform.tfstate.backup"
        rm -rf "$SCRIPT_DIR/.terraform"
        rm -f "$SCRIPT_DIR/.terraform.lock.hcl"
        
        echo -e "${GREEN}✓ Local files cleaned${NC}"
        echo ""
        
        echo -e "${BLUE}Cleanup complete. You can now run the demo setup again if needed.${NC}"
    else
        echo ""
        echo -e "${RED}=================================${NC}"
        echo -e "${RED}Cleanup Failed!${NC}"
        echo -e "${RED}=================================${NC}"
        echo ""
        echo -e "${RED}Some resources may not have been destroyed.${NC}"
        echo -e "${YELLOW}Please check the AWS Console and manually delete any remaining resources.${NC}"
        echo ""
        exit 1
    fi
fi
