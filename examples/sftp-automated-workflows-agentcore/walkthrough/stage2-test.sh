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

# Script directory (parent of code-talk folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Always re-zip claims to ensure latest files
echo -e "${YELLOW}Creating ZIP files for claims...${NC}"
"$SCRIPT_DIR/code-talk/zip-claims.sh"
echo ""

ZIPPED_DIR="$SCRIPT_DIR/data/zipped"
CLAIM1_ZIP="$ZIPPED_DIR/claim-1.zip"

# Create EICAR test file (obfuscated to avoid false positives in git)
# EICAR is a standard test file that antivirus software recognizes as malware
EICAR_FILE="/tmp/eicar-test-file.txt"
EICAR_ZIP="/tmp/eicar-malware.zip"
echo -e "${YELLOW}Creating EICAR test file for malware detection...${NC}"

# Construct EICAR string from parts to avoid triggering scanners
EICAR_PART1="X5O!P%@AP[4\\PZX54(P^)7CC)7}"
EICAR_PART2='$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
echo "$EICAR_PART1$EICAR_PART2" > "$EICAR_FILE"

# Zip the EICAR file
(cd /tmp && zip -q "$EICAR_ZIP" eicar-test-file.txt)

echo -e "${GREEN}✓ EICAR test file created and zipped${NC}"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}SFTP Connection Details${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Username:${NC} $COGNITO_USERNAME"
echo -e "${BLUE}Server:${NC} $TRANSFER_SERVER_ENDPOINT"
echo -e "${BLUE}Password:${NC} (copied to clipboard)"
echo -e "${BLUE}Claim ZIP file:${NC} claim-1.zip"
echo -e "${BLUE}Test malware ZIP:${NC} eicar-malware.zip"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Upload files via SFTP
echo -e "${YELLOW}Uploading claim-1.zip and EICAR malware ZIP via SFTP...${NC}"
echo ""

# Build SFTP commands - upload claim-1.zip and EICAR ZIP
SFTP_COMMANDS="put \"$CLAIM1_ZIP\"\nput \"$EICAR_ZIP\"\nls -l\nbye\n"

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
echo -e "${GREEN}Monitoring Malware Scan Status Tags${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Files to monitor
CLAIM_FILE="claim-1.zip"
EICAR_FILE_KEY="eicar-malware.zip"

echo -e "${BLUE}Monitoring files:${NC}"
echo -e "  1. $CLAIM_FILE (should be clean)"
echo -e "  2. $EICAR_FILE_KEY (should detect threat)"
echo -e "${BLUE}Upload bucket:${NC} $UPLOAD_BUCKET"
echo ""
echo -e "${YELLOW}Checking GuardDutyMalwareScanStatus tags on uploaded ZIP files...${NC}"
echo ""

MAX_ATTEMPTS=30
ATTEMPT=0
CLAIM_SCAN_COMPLETE=false
EICAR_SCAN_COMPLETE=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # Check claim file scan status tag
    CLAIM_SCAN_STATUS=$(aws s3api get-object-tagging --bucket "$UPLOAD_BUCKET" --key "$CLAIM_FILE" --query 'TagSet[?Key==`GuardDutyMalwareScanStatus`].Value' --output text 2>/dev/null || echo "")
    
    # Check EICAR file scan status tag
    EICAR_SCAN_STATUS=$(aws s3api get-object-tagging --bucket "$UPLOAD_BUCKET" --key "$EICAR_FILE_KEY" --query 'TagSet[?Key==`GuardDutyMalwareScanStatus`].Value' --output text 2>/dev/null || echo "")
    
    # Show current status
    echo -e "${BLUE}Check $((ATTEMPT + 1))/$MAX_ATTEMPTS:${NC}"
    
    # Claim file status
    if [ -z "$CLAIM_SCAN_STATUS" ]; then
        echo -e "  ${YELLOW}Claim file:${NC} No scan tag yet..."
    else
        if [ "$CLAIM_SCAN_STATUS" = "NO_THREATS_FOUND" ]; then
            echo -e "  ${GREEN}Claim file:${NC} GuardDutyMalwareScanStatus = ${GREEN}$CLAIM_SCAN_STATUS${NC}"
        else
            echo -e "  ${BLUE}Claim file:${NC} GuardDutyMalwareScanStatus = ${BLUE}$CLAIM_SCAN_STATUS${NC}"
        fi
        if [ "$CLAIM_SCAN_STATUS" != "PENDING" ]; then
            CLAIM_SCAN_COMPLETE=true
        fi
    fi
    
    # EICAR file status
    if [ -z "$EICAR_SCAN_STATUS" ]; then
        echo -e "  ${YELLOW}EICAR file:${NC} No scan tag yet..."
    else
        if [ "$EICAR_SCAN_STATUS" = "THREATS_FOUND" ]; then
            echo -e "  ${RED}EICAR file:${NC} GuardDutyMalwareScanStatus = ${RED}$EICAR_SCAN_STATUS${NC}"
        else
            echo -e "  ${BLUE}EICAR file:${NC} GuardDutyMalwareScanStatus = ${BLUE}$EICAR_SCAN_STATUS${NC}"
        fi
        if [ "$EICAR_SCAN_STATUS" != "PENDING" ]; then
            EICAR_SCAN_COMPLETE=true
        fi
    fi
    
    echo ""
    
    # Check if both scans are complete
    if [ "$CLAIM_SCAN_COMPLETE" = true ] && [ "$EICAR_SCAN_COMPLETE" = true ]; then
        break
    fi
    
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$CLAIM_SCAN_COMPLETE" = true ] && [ "$EICAR_SCAN_COMPLETE" = true ]; then
    echo -e "${GREEN}✓ Both malware scans completed!${NC}"
    echo ""
    echo -e "${BLUE}Final Scan Results:${NC}"
    echo -e "  Claim file: ${GREEN}$CLAIM_SCAN_STATUS${NC}"
    echo -e "  EICAR file: ${RED}$EICAR_SCAN_STATUS${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ Scans still in progress after $MAX_ATTEMPTS attempts. Continuing...${NC}"
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
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Quarantine Bucket (Threats Detected)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# List files in quarantine bucket
echo -e "${BLUE}Quarantine Bucket:${NC} $QUARANTINE_BUCKET"
echo ""
echo -e "${BLUE}Command:${NC} aws s3 ls s3://$QUARANTINE_BUCKET/ --recursive --human-readable --summarize"
echo ""
echo -e "${YELLOW}Press Enter to list quarantine bucket...${NC}"
read -r
echo ""
echo -e "${YELLOW}Quarantined files (threats detected):${NC}"
aws s3 ls "s3://$QUARANTINE_BUCKET/" --recursive --human-readable --summarize

echo ""
echo -e "${GREEN}✓ Test completed!${NC}"
echo ""

# Prompt to clean up test files
echo -e "${YELLOW}Press Enter to clean up test files from all buckets...${NC}"
read -r

echo ""
echo -e "${YELLOW}Cleaning up test files...${NC}"

# Delete claim-1 ZIP and extracted files from all buckets
echo "  Deleting claim-1.zip from upload bucket..."
aws s3 rm "s3://$UPLOAD_BUCKET/claim-1.zip" 2>/dev/null || true
echo "  Deleting submitted-claims/claim-1/ from clean bucket..."
aws s3 rm "s3://$CLEAN_BUCKET/submitted-claims/claim-1/" --recursive 2>/dev/null || true
echo "  Deleting submitted-claims/claim-1/ from quarantine bucket..."
aws s3 rm "s3://$QUARANTINE_BUCKET/submitted-claims/claim-1/" --recursive 2>/dev/null || true

# Delete EICAR ZIP from all buckets
echo "  Deleting eicar-malware.zip from upload bucket..."
aws s3 rm "s3://$UPLOAD_BUCKET/eicar-malware.zip" 2>/dev/null || true
echo "  Deleting eicar-malware.zip from clean bucket..."
aws s3 rm "s3://$CLEAN_BUCKET/eicar-malware.zip" 2>/dev/null || true
echo "  Deleting eicar-malware.zip from quarantine bucket..."
aws s3 rm "s3://$QUARANTINE_BUCKET/eicar-malware.zip" 2>/dev/null || true

# Clean up local EICAR files
rm -f "$EICAR_FILE" "$EICAR_ZIP"

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
echo ""
echo -e "${YELLOW}Quarantine bucket:${NC}"
aws s3 ls "s3://$QUARANTINE_BUCKET/" --recursive --human-readable --summarize
