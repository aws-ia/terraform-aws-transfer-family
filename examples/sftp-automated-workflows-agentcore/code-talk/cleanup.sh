#!/bin/bash

################################################################################
# Cleanup Script
# Removes all objects from S3 buckets and destroys infrastructure
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

echo -e "${RED}=================================${NC}"
echo -e "${RED}Infrastructure Cleanup${NC}"
echo -e "${RED}=================================${NC}"
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will destroy all infrastructure and delete all data!${NC}"
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
            aws s3api list-object-versions --bucket "$bucket" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
                jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
                xargs -I {} aws s3api delete-object --bucket "$bucket" {} 2>/dev/null || true
            
            # Delete all delete markers
            aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null | \
                jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
                xargs -I {} aws s3api delete-object --bucket "$bucket" {} 2>/dev/null || true
            
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

echo ""
echo -e "${GREEN}✓ All S3 buckets cleaned${NC}"
echo ""

# Destroy infrastructure
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Destroying Infrastructure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Running terraform destroy...${NC}"
echo ""
echo -e "${BLUE}Command:${NC} terraform destroy -auto-approve -compact-warnings"
echo ""
echo -e "${YELLOW}Press Enter to destroy infrastructure...${NC}"
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

echo -e "${BLUE}Cleanup complete. You can now run the demo setup again if needed.${NC}"
