#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Claims Processing Results${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${YELLOW}📊 S3 Buckets Status:${NC}\n"

echo -e "${CYAN}Transfer Bucket (SFTP uploads):${NC}"
aws s3 ls s3://anycompany-repairs-darling-werewolf-claims-files --recursive --region us-east-1 2>&1 | head -10

echo -e "\n${GREEN}Clean Bucket (After malware scan):${NC}"
aws s3 ls s3://aws-ia-mutual-adder-claims-clean --recursive --region us-east-1 2>&1 | head -10

echo -e "\n${RED}Quarantine Bucket (Infected files):${NC}"
aws s3 ls s3://aws-ia-mutual-adder-claims-quarantine --recursive --region us-east-1 2>&1 | head -10

echo -e "\n${YELLOW}📝 DynamoDB Claims:${NC}\n"
aws dynamodb scan --table-name claims-table --region us-east-1 --query 'Items[*].[claim_id.S, vehicle_make.S, vehicle_model.S, damage_consistent.BOOL, validation_confidence.N]' --output table 2>&1

echo -e "\n${GREEN}📄 Latest Summary Report:${NC}\n"
LATEST=$(aws s3 ls s3://aws-ia-mutual-adder-claims-clean/processed-claims/ --recursive --region us-east-1 2>&1 | sort | tail -1 | awk '{print $4}')
if [ ! -z "$LATEST" ]; then
    echo -e "${CYAN}Report: $LATEST${NC}\n"
    aws s3 cp s3://aws-ia-mutual-adder-claims-clean/$LATEST - --region us-east-1 2>&1
else
    echo -e "${RED}No reports generated yet${NC}"
fi
