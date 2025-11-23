#!/bin/bash

################################################################################
# Stage 2 Test Script
# Tests SFTP upload and monitors malware scan results
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
echo -e "${BLUE}Stage 2: Malware Protection Test${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check if Terraform state exists
if [ ! -f "$SCRIPT_DIR/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform state not found. Please run stage2-deploy.sh first.${NC}"
    exit 1
fi

# Extract outputs
echo -e "${YELLOW}Retrieving connection information...${NC}"
echo ""

COGNITO_USERNAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_username 2>/dev/null || echo "")
COGNITO_PASSWORD_SECRET_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_password_secret_arn 2>/dev/null || echo "")
TRANSFER_SERVER_ENDPOINT=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_server_endpoint 2>/dev/null || echo "")
UPLOAD_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_upload_bucket_name 2>/dev/null || echo "")
CLEAN_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_clean_bucket_name 2>/dev/null || echo "")
QUARANTINE_BUCKET=$(terraform -chdir="$SCRIPT_DIR" output -raw malware_quarantine_bucket_name 2>/dev/null || echo "")

# Validate outputs
if [ -z "$COGNITO_USERNAME" ] || [ -z "$COGNITO_PASSWORD_SECRET_ARN" ] || [ -z "$TRANSFER_SERVER_ENDPOINT" ] || [ -z "$UPLOAD_BUCKET" ] || [ -z "$CLEAN_BUCKET" ]; then
    echo -e "${RED}Error: Unable to retrieve required connection information.${NC}"
    echo -e "${RED}Please ensure Stage 2 has been deployed successfully.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connection information retrieved${NC}"
echo ""

# Retrieve and copy password to clipboard
echo -e "${YELLOW}Retrieving password from Secrets Manager...${NC}"
PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$COGNITO_PASSWORD_SECRET_ARN" --query SecretString --output text 2>/dev/null | jq -r .password 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Failed to retrieve password from Secrets Manager.${NC}"
    echo -e "${RED}Please ensure you have the necessary AWS permissions.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Password retrieved${NC}"
echo ""

# Copy password to clipboard
echo -e "${YELLOW}Copying password to clipboard...${NC}"

# Detect OS and use appropriate clipboard command
if command -v pbcopy &> /dev/null; then
    # macOS
    echo -n "$PASSWORD" | pbcopy
    echo -e "${GREEN}✓ Password copied to clipboard (macOS)${NC}"
elif command -v xclip &> /dev/null; then
    # Linux with xclip
    echo -n "$PASSWORD" | xclip -selection clipboard
    echo -e "${GREEN}✓ Password copied to clipboard (Linux)${NC}"
elif command -v xsel &> /dev/null; then
    # Linux with xsel
    echo -n "$PASSWORD" | xsel --clipboard --input
    echo -e "${GREEN}✓ Password copied to clipboard (Linux)${NC}"
elif command -v clip.exe &> /dev/null; then
    # WSL
    echo -n "$PASSWORD" | clip.exe
    echo -e "${GREEN}✓ Password copied to clipboard (WSL)${NC}"
else
    echo -e "${YELLOW}⚠ Clipboard utility not found.${NC}"
    echo -e "${YELLOW}Password: $PASSWORD${NC}"
fi

echo ""

# Set claim-1 folder path
CLAIM_DIR="$SCRIPT_DIR/data/claim-1"

# Get all files in claim-1 folder
CLAIMS_FILES=($(find "$CLAIM_DIR" -type f \( -name "*.pdf" -o -name "*.png" -o -name "*.jpg" -o -name "*.json" \) 2>/dev/null))

echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}SFTP Connection Details${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Username:${NC} $COGNITO_USERNAME"
echo -e "${BLUE}Server:${NC} $TRANSFER_SERVER_ENDPOINT"
echo -e "${BLUE}Password:${NC} (copied to clipboard)"
echo -e "${BLUE}Files to upload:${NC} ${#CLAIMS_FILES[@]}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Upload files via SFTP
echo -e "${YELLOW}Uploading claims files via SFTP...${NC}"
echo ""

# Build SFTP commands - recursively copy the entire claim-1 folder
SFTP_COMMANDS="put -r \"$CLAIM_DIR\"\nls -l\nbye\n"

# Execute SFTP with commands piped via stdin
echo -e "${BLUE}Connecting to SFTP server...${NC}"
echo -e "${YELLOW}You will be prompted for the password (it's in your clipboard)${NC}"
echo ""
echo -e "${BLUE}Command:${NC} sftp $COGNITO_USERNAME@$TRANSFER_SERVER_ENDPOINT"
echo ""
echo -e "${YELLOW}Press Enter to start SFTP session...${NC}"
read -r

echo -e "$SFTP_COMMANDS" | sftp "$COGNITO_USERNAME@$TRANSFER_SERVER_ENDPOINT"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Upload completed!${NC}"
else
    echo ""
    echo -e "${RED}✗ Upload failed. Please check the connection and try again.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Monitoring Malware Scan${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get first file to monitor (with claim-1 folder path)
TEST_FILE="claim-1/$(basename "${CLAIMS_FILES[0]}")"
echo -e "${BLUE}Monitoring file:${NC} $TEST_FILE"
echo -e "${BLUE}Upload bucket:${NC} $UPLOAD_BUCKET"
echo ""

# Monitor for scan result
echo -e "${YELLOW}Waiting for malware scan to complete...${NC}"
echo ""

MAX_ATTEMPTS=30
ATTEMPT=0
SCAN_COMPLETE=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Check if file has GuardDuty scan result tag
    SCAN_STATUS=$(aws s3api get-object-tagging --bucket "$UPLOAD_BUCKET" --key "$TEST_FILE" --query 'TagSet[?Key==`GuardDutyMalwareScanStatus`].Value' --output text 2>/dev/null || echo "")
    
    # Show current status
    if [ -z "$SCAN_STATUS" ]; then
        echo -e "${YELLOW}Check $((ATTEMPT + 1))/$MAX_ATTEMPTS:${NC} No scan tag yet..."
    else
        echo -e "${BLUE}Check $((ATTEMPT + 1))/$MAX_ATTEMPTS:${NC} GuardDutyMalwareScanStatus = ${GREEN}$SCAN_STATUS${NC}"
        
        # Check if scan is complete (any status other than empty means scan finished)
        if [ "$SCAN_STATUS" != "PENDING" ]; then
            SCAN_COMPLETE=true
            break
        fi
    fi
    
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

echo ""

if [ "$SCAN_COMPLETE" = true ]; then
    echo -e "${GREEN}✓ Malware scan completed!${NC}"
    echo ""
    echo -e "${BLUE}Final Scan Result:${NC} $SCAN_STATUS"
    echo ""
else
    echo -e "${YELLOW}⚠ Scan still in progress after $MAX_ATTEMPTS attempts. Continuing...${NC}"
    echo ""
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Clean Files Bucket${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# List files in clean bucket
echo -e "${BLUE}Clean Bucket:${NC} $CLEAN_BUCKET"
echo ""
echo -e "${BLUE}Command:${NC} aws s3 ls s3://$CLEAN_BUCKET/ --recursive --human-readable --summarize"
echo ""
echo -e "${YELLOW}Press Enter to list clean files bucket...${NC}"
read -r
echo ""
echo -e "${YELLOW}Clean files (passed malware scan):${NC}"
aws s3 ls "s3://$CLEAN_BUCKET/" --recursive --human-readable --summarize

echo ""
echo -e "${GREEN}✓ Test completed!${NC}"
echo ""

# Prompt to clean up test files
echo -e "${YELLOW}Press Enter to clean up test files from all buckets...${NC}"
read -r

echo ""
echo -e "${YELLOW}Cleaning up test files...${NC}"

# Delete uploaded files from all buckets (including claim-1 folder)
for file in "${CLAIMS_FILES[@]}"; do
    FILENAME=$(basename "$file")
    echo "  Deleting claim-1/$FILENAME from upload bucket..."
    aws s3 rm "s3://$UPLOAD_BUCKET/claim-1/$FILENAME" 2>/dev/null || true
    echo "  Deleting claim-1/$FILENAME from clean bucket..."
    aws s3 rm "s3://$CLEAN_BUCKET/claim-1/$FILENAME" 2>/dev/null || true
    echo "  Deleting claim-1/$FILENAME from quarantine bucket..."
    aws s3 rm "s3://$QUARANTINE_BUCKET/claim-1/$FILENAME" 2>/dev/null || true
done

echo ""
echo -e "${GREEN}✓ Cleanup completed!${NC}"
echo ""

# Show final bucket states
echo -e "${BLUE}Final bucket contents:${NC}"
echo ""
echo -e "${YELLOW}Upload bucket:${NC}"
aws s3 ls "s3://$UPLOAD_BUCKET/" --recursive --human-readable --summarize
echo ""
echo -e "${YELLOW}Clean bucket:${NC}"
aws s3 ls "s3://$CLEAN_BUCKET/" --recursive --human-readable --summarize
