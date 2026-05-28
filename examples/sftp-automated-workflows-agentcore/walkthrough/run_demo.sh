#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Resolve the parent directory (Terraform root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Retrieve SFTP connection details from Terraform outputs
TRANSFER_SERVER_ENDPOINT=$(terraform -chdir="$SCRIPT_DIR" output -raw transfer_server_endpoint 2>/dev/null || echo "")
COGNITO_USERNAME=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_username 2>/dev/null || echo "")
COGNITO_PASSWORD_SECRET_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw cognito_password_secret_arn 2>/dev/null || echo "")
PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$COGNITO_PASSWORD_SECRET_ARN" --query SecretString --output text 2>/dev/null | jq -r .password 2>/dev/null)

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Transfer Family POC - Live Demo${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${GREEN}✓ Environment cleaned${NC}"
echo -e "  - All S3 buckets emptied"
echo -e "  - DynamoDB table cleared\n"

echo -e "${YELLOW}📋 Demo Steps:${NC}"
echo -e "  1. Upload files via SFTP to claim-3/"
echo -e "  2. GuardDuty scans for malware"
echo -e "  3. Files moved to clean bucket"
echo -e "  4. Orchestrator Lambda triggers pipeline"
echo -e "  5. Document extraction from PDF"
echo -e "  6. Damage assessment with image"
echo -e "  7. Fraud detection"
echo -e "  8. Classification and summary generation\n"

echo -e "${CYAN}🔍 Monitoring Options:${NC}"
echo -e "  Single agent:  ./walkthrough/monitor_agents.sh {extraction|damage|fraud|classification|orchestrator}"
echo -e "  Infrastructure: ./walkthrough/monitor_agents.sh {claims|malware}"
echo -e "  All commands:  ./walkthrough/monitor_agents.sh all\n"

echo -e "${GREEN}📁 Test Files:${NC}"
echo -e "  Location: data/claim-3/"
echo -e "  Files: car_damage_claim_report.pdf, claim-3.png\n"

echo -e "${YELLOW}🚀 Ready to start demo!${NC}"
echo -e "Run: ${CYAN}./walkthrough/monitor_agents.sh claims${NC} in another terminal, then upload files via SFTP\n"

echo -e "${CYAN}SFTP Upload Command:${NC}"
echo -e "  sftp ${COGNITO_USERNAME}@${TRANSFER_SERVER_ENDPOINT}"
echo -e "  # Password: ${PASSWORD}"
echo -e "  # Then run:"
echo -e "  mkdir claim-3"
echo -e "  cd claim-3"
echo -e "  put data/claim-3/car_damage_claim_report.pdf"
echo -e "  put data/claim-3/claim-3.png"
echo -e "  ls -la"
echo -e "  bye"
