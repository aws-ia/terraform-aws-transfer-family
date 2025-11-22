#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
echo -e "  4. Lambda triggers workflow agent"
echo -e "  5. Entity extraction from PDF"
echo -e "  6. Fraud validation with image"
echo -e "  7. Database insertion"
echo -e "  8. Summary report generation\n"

echo -e "${CYAN}🔍 Monitoring Options:${NC}"
echo -e "  Single agent:  ./demo/monitor_agents.sh {workflow|entity|fraud|database|summary}"
echo -e "  Infrastructure: ./demo/monitor_agents.sh {claims|malware}"
echo -e "  All commands:  ./demo/monitor_agents.sh all\n"

echo -e "${GREEN}📁 Test Files:${NC}"
echo -e "  Location: data/claim-3/"
echo -e "  Files: car_damage_claim_report.pdf, claim-3.png\n"

echo -e "${YELLOW}🚀 Ready to start demo!${NC}"
echo -e "Run: ${CYAN}./demo/monitor_agents.sh claims${NC} in another terminal, then upload files via SFTP\n"

echo -e "${CYAN}SFTP Upload Command:${NC}"
cat << 'EOF'
cd /Users/sekhrip/Documents/Code/transfer-family-poc-reinvent
sftp anycompany-repairs@s-a58dd1620ef943f4b.server.transfer.us-east-1.amazonaws.com
# Password: iCr05*yfSRPx!{BY
# Then run:
mkdir claim-3
cd claim-3
put data/claim-3/car_damage_claim_report.pdf
put data/claim-3/claim-3.png
ls -la
bye
EOF
