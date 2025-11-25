#!/bin/bash

################################################################################
# Stage 3 Test Script
# Tests SFTP upload, malware scan, and AI claims processing
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory (parent of code-talk folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Stage 3: AI Claims Processing Test${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check if Terraform state exists
if [ ! -f "$SCRIPT_DIR/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform state not found. Please run stage3-deploy.sh first.${NC}"
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
WORKFLOW_AGENT_ID=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_workflow_agent_runtime_id 2>/dev/null || echo "")
CLAIMS_TABLE=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_claims_table_name 2>/dev/null || echo "")

# Validate outputs
if [ -z "$COGNITO_USERNAME" ] || [ -z "$COGNITO_PASSWORD_SECRET_ARN" ] || [ -z "$TRANSFER_SERVER_ENDPOINT" ] || [ -z "$UPLOAD_BUCKET" ] || [ -z "$CLEAN_BUCKET" ] || [ -z "$WORKFLOW_AGENT_ID" ]; then
    echo -e "${RED}Error: Unable to retrieve required connection information.${NC}"
    echo -e "${RED}Please ensure Stage 3 has been deployed successfully.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connection information retrieved${NC}"
echo ""

# Display workflow agent information
echo -e "${BLUE}Workflow Agent ID:${NC} $WORKFLOW_AGENT_ID"
echo -e "${BLUE}Claims Table:${NC} $CLAIMS_TABLE"
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

echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}SFTP Connection Details${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Username:${NC} $COGNITO_USERNAME"
echo -e "${BLUE}Server:${NC} $TRANSFER_SERVER_ENDPOINT"
echo -e "${BLUE}Password:${NC} (copied to clipboard)"
echo -e "${BLUE}Claim ZIP file:${NC} claim-1.zip"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Upload files via SFTP
echo -e "${YELLOW}Uploading claim-1.zip via SFTP...${NC}"
echo ""

# Build SFTP commands - upload claim-1.zip
SFTP_COMMANDS="put \"$CLAIM1_ZIP\"\nls -l\nbye\n"

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
echo -e "${GREEN}Monitoring AI Claims Processing${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BLUE}Workflow Agent:${NC} $WORKFLOW_AGENT_ID"
echo -e "${BLUE}Claims Table:${NC} $CLAIMS_TABLE"
echo ""

echo -e "${YELLOW}Monitoring agent logs for claims processing...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop monitoring early${NC}"
echo ""

# Monitor logs for a period
START_TIME=$(($(date +%s) * 1000))
MAX_MONITOR_TIME=90  # Monitor for 90 seconds
MONITOR_START=$(date +%s)

echo -e "${CYAN}[Watching all agent activity for up to 90 seconds]${NC}"
echo ""

# Temporarily disable exit on error for monitoring loop
set +e

# Set up trap to catch Ctrl+C
STOP_MONITORING=false
trap 'STOP_MONITORING=true; echo' INT

while [ $(($(date +%s) - MONITOR_START)) -lt $MAX_MONITOR_TIME ] && [ "$STOP_MONITORING" = false ]; do
    # Find all log groups for agentcore runtimes (refresh each loop)
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/bedrock-agentcore/runtimes/" \
        --query 'logGroups[].logGroupName' \
        --output text 2>/dev/null || echo "")
    
    # Fetch recent log events from all log groups
    for LOG_GROUP in $LOG_GROUPS; do
        # Extract agent name from log group path
        AGENT_NAME=$(echo "$LOG_GROUP" | sed 's|.*/runtimes/||' | cut -d'-' -f1)
        
        # Use JSON output and parse with jq to properly handle newlines
        aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --start-time $START_TIME \
            --output json 2>/dev/null | \
            jq -r '.events[]?.message // empty' 2>/dev/null | \
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    # Color code by agent type
                    case "$AGENT_NAME" in
                        *workflow*)
                            echo -e "${MAGENTA}[WORKFLOW]${NC} $line"
                            ;;
                        *entity*)
                            echo -e "${BLUE}[ENTITY]${NC} $line"
                            ;;
                        *validation*|*fraud*)
                            echo -e "${RED}[FRAUD]${NC} $line"
                            ;;
                        *database*)
                            echo -e "${YELLOW}[DATABASE]${NC} $line"
                            ;;
                        *summary*)
                            echo -e "${GREEN}[SUMMARY]${NC} $line"
                            ;;
                        *)
                            echo -e "${CYAN}[AGENT]${NC} $line"
                            ;;
                    esac
                fi
            done
    done
    
    START_TIME=$(($(date +%s) * 1000))
    sleep 3
done

# Reset trap and re-enable exit on error
trap - INT
set -e

echo ""
if [ "$STOP_MONITORING" = true ]; then
    echo -e "${YELLOW}✓ Monitoring stopped by user${NC}"
else
    echo -e "${GREEN}✓ Monitoring period completed${NC}"
fi
echo ""

# Check DynamoDB for processed claims
echo -e "${YELLOW}Checking DynamoDB for processed claims...${NC}"
echo ""
echo -e "${BLUE}Command:${NC} aws dynamodb scan --table-name $CLAIMS_TABLE --max-items 5"
echo ""
echo -e "${YELLOW}Press Enter to view processed claims...${NC}"
read -r
echo ""

aws dynamodb scan --table-name "$CLAIMS_TABLE" --max-items 5 --output json | jq -r '.Items[] | "Claim ID: \(.claim_id.S // "N/A")\nStatus: \(.status.S // "N/A")\nTimestamp: \(.timestamp.S // "N/A")\n---"'

echo ""
echo -e "${GREEN}✓ Claim-1 test completed!${NC}"
echo ""

################################################################################
# Test Claim-2
################################################################################

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Testing Claim-2 Submission${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Ready to test claim-2 submission?${NC}"
echo -e "${YELLOW}Press Enter to upload claim-2 files...${NC}"
read -r

# Set claim-2 ZIP path
CLAIM2_ZIP="$ZIPPED_DIR/claim-2.zip"

echo ""
echo -e "${BLUE}Claim ZIP file:${NC} claim-2.zip"
echo ""

# Build SFTP commands for claim-2
SFTP_COMMANDS2="put \"$CLAIM2_ZIP\"\nls -l\nbye\n"

echo -e "${BLUE}Uploading claim-2 files via SFTP...${NC}"
echo -e "${YELLOW}You will be prompted for the password (it's in your clipboard)${NC}"
echo ""

echo -e "$SFTP_COMMANDS2" | sftp "$COGNITO_USERNAME@$TRANSFER_SERVER_ENDPOINT"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Claim-2 upload completed!${NC}"
else
    echo ""
    echo -e "${RED}✗ Claim-2 upload failed.${NC}"
fi

echo ""
echo -e "${YELLOW}Monitoring claim-2 processing...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop monitoring early${NC}"
echo ""

# Monitor logs for claim-2 processing
START_TIME=$(($(date +%s) * 1000))
MAX_MONITOR_TIME=90
MONITOR_START=$(date +%s)

echo -e "${CYAN}[Watching agent activity for claim-2 for up to 90 seconds]${NC}"
echo ""

# Temporarily disable exit on error for monitoring loop
set +e

# Set up trap to catch Ctrl+C
STOP_MONITORING2=false
trap 'STOP_MONITORING2=true; echo' INT

while [ $(($(date +%s) - MONITOR_START)) -lt $MAX_MONITOR_TIME ] && [ "$STOP_MONITORING2" = false ]; do
    # Find all log groups for agentcore runtimes (refresh each loop)
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/bedrock-agentcore/runtimes/" \
        --query 'logGroups[].logGroupName' \
        --output text 2>/dev/null || echo "")
    
    # Fetch recent log events from all log groups
    for LOG_GROUP in $LOG_GROUPS; do
        # Extract agent name from log group path
        AGENT_NAME=$(echo "$LOG_GROUP" | sed 's|.*/runtimes/||' | cut -d'-' -f1)
        
        # Use JSON output and parse with jq to properly handle newlines
        aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --start-time $START_TIME \
            --output json 2>/dev/null | \
            jq -r '.events[]?.message // empty' 2>/dev/null | \
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    # Color code by agent type
                    case "$AGENT_NAME" in
                        *workflow*)
                            echo -e "${MAGENTA}[WORKFLOW]${NC} $line"
                            ;;
                        *entity*)
                            echo -e "${BLUE}[ENTITY]${NC} $line"
                            ;;
                        *validation*|*fraud*)
                            echo -e "${RED}[FRAUD]${NC} $line"
                            ;;
                        *database*)
                            echo -e "${YELLOW}[DATABASE]${NC} $line"
                            ;;
                        *summary*)
                            echo -e "${GREEN}[SUMMARY]${NC} $line"
                            ;;
                        *)
                            echo -e "${CYAN}[AGENT]${NC} $line"
                            ;;
                    esac
                fi
            done
    done
    
    START_TIME=$(($(date +%s) * 1000))
    sleep 3
done

# Reset trap and re-enable exit on error
trap - INT
set -e

echo ""
if [ "$STOP_MONITORING2" = true ]; then
    echo -e "${YELLOW}✓ Monitoring stopped by user${NC}"
else
    echo -e "${GREEN}✓ Claim-2 monitoring completed${NC}"
fi
echo ""

# Check DynamoDB for all processed claims
echo -e "${YELLOW}Checking DynamoDB for all processed claims...${NC}"
echo ""
echo -e "${BLUE}Command:${NC} aws dynamodb scan --table-name $CLAIMS_TABLE"
echo ""
echo -e "${YELLOW}Press Enter to view all processed claims...${NC}"
read -r
echo ""

aws dynamodb scan --table-name "$CLAIMS_TABLE" --output json | jq -r '.Items[] | "Claim ID: \(.claim_id.S // "N/A")\nStatus: \(.status.S // "N/A")\nTimestamp: \(.timestamp.S // "N/A")\n---"'

echo ""
echo -e "${GREEN}✓ All tests completed!${NC}"
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

# Delete claim-2 ZIP and extracted files from all buckets
echo "  Deleting claim-2.zip from upload bucket..."
aws s3 rm "s3://$UPLOAD_BUCKET/claim-2.zip" 2>/dev/null || true
echo "  Deleting submitted-claims/claim-2/ from clean bucket..."
aws s3 rm "s3://$CLEAN_BUCKET/submitted-claims/claim-2/" --recursive 2>/dev/null || true
echo "  Deleting submitted-claims/claim-2/ from quarantine bucket..."
aws s3 rm "s3://$QUARANTINE_BUCKET/submitted-claims/claim-2/" --recursive 2>/dev/null || true

echo ""
echo -e "${GREEN}✓ Cleanup completed!${NC}"
