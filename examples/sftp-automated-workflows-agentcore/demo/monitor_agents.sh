#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Claims Processing Agents Monitor${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Resolve script directory for Terraform output lookups
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Retrieve agent runtime ARNs from Terraform outputs
EXTRACTION_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_document_extraction_agent_arn 2>/dev/null || echo "")
DAMAGE_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_damage_assessment_agent_arn 2>/dev/null || echo "")
FRAUD_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_fraud_detection_agent_arn 2>/dev/null || echo "")
CLASSIFICATION_ARN=$(terraform -chdir="$SCRIPT_DIR" output -raw agentcore_classification_agent_arn 2>/dev/null || echo "")

# Derive log group from agent runtime ARN
# ARN format: arn:aws:bedrock-agentcore:region:account:runtime/RUNTIME_NAME
# Log group pattern: /aws/bedrock-agentcore/runtimes/{runtime_name}
get_agent_log_group() {
    local arn=$1
    if [ -z "$arn" ]; then
        echo ""
        return
    fi
    local runtime_name
    runtime_name=$(echo "$arn" | awk -F'/' '{print $NF}')
    local log_group
    log_group=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/bedrock-agentcore/runtimes/$runtime_name" \
        --query 'logGroups[0].logGroupName' --output text 2>/dev/null || echo "")
    if [ "$log_group" = "None" ]; then
        echo ""
    else
        echo "$log_group"
    fi
}

# Discover agent log groups dynamically
EXTRACTION_LOG_GROUP=$(get_agent_log_group "$EXTRACTION_ARN")
DAMAGE_LOG_GROUP=$(get_agent_log_group "$DAMAGE_ARN")
FRAUD_LOG_GROUP=$(get_agent_log_group "$FRAUD_ARN")
CLASSIFICATION_LOG_GROUP=$(get_agent_log_group "$CLASSIFICATION_ARN")

# Orchestrator Lambda log group
ORCHESTRATOR_LAMBDA="/aws/lambda/tf-demo-claims-orchestrator"

# Malware scanner Lambda log group
MALWARE_LAMBDA="/aws/lambda/mp-aws-ia-mutual-adder-file-transfer-function"

tail_logs() {
    local log_group=$1
    local label=$2
    local color=$3
    local start_time=$(($(date +%s) * 1000))
    
    echo -e "${color}[${label}]${NC} Monitoring logs (press Ctrl+C to stop)..."
    
    while true; do
        aws logs filter-log-events \
            --log-group-name "$log_group" \
            --start-time $start_time \
            --region us-east-1 \
            --query 'events[*].message' \
            --output text 2>/dev/null | while read -r line; do
            if [ ! -z "$line" ]; then
                echo -e "${color}[${label}]${NC} $line"
            fi
        done
        start_time=$(($(date +%s) * 1000))
        sleep 2
    done
}

case "$1" in
    "extraction")
        tail_logs "$EXTRACTION_LOG_GROUP" "EXTRACTION" "$BLUE"
        ;;
    "damage")
        tail_logs "$DAMAGE_LOG_GROUP" "DAMAGE" "$MAGENTA"
        ;;
    "fraud")
        tail_logs "$FRAUD_LOG_GROUP" "FRAUD" "$RED"
        ;;
    "classification")
        tail_logs "$CLASSIFICATION_LOG_GROUP" "CLASSIFICATION" "$YELLOW"
        ;;
    "orchestrator")
        tail_logs "$ORCHESTRATOR_LAMBDA" "ORCHESTRATOR" "$CYAN"
        ;;
    "malware")
        tail_logs "$MALWARE_LAMBDA" "MALWARE" "$YELLOW"
        ;;
    "all")
        echo -e "${WHITE}Starting all agent monitors...${NC}\n"
        echo -e "${WHITE}Open separate terminals and run:${NC}"
        echo -e "  ${BLUE}Terminal 1:${NC} $0 extraction"
        echo -e "  ${MAGENTA}Terminal 2:${NC} $0 damage"
        echo -e "  ${RED}Terminal 3:${NC} $0 fraud"
        echo -e "  ${YELLOW}Terminal 4:${NC} $0 classification"
        echo -e "  ${CYAN}Terminal 5:${NC} $0 orchestrator"
        echo -e "  ${YELLOW}Terminal 6:${NC} $0 malware"
        ;;
    *)
        echo "Usage: $0 {extraction|damage|fraud|classification|orchestrator|malware|all}"
        echo ""
        echo "Agents:"
        echo "  extraction      - Document extraction agent (reads PDF)"
        echo "  damage          - Damage assessment agent (analyzes damage)"
        echo "  fraud           - Fraud detection agent (checks for fraud)"
        echo "  classification  - Classification agent (routes claims)"
        echo ""
        echo "Infrastructure:"
        echo "  orchestrator  - Claims orchestrator Lambda (coordinates pipeline)"
        echo "  malware       - Malware scanner Lambda (GuardDuty integration)"
        echo ""
        echo "  all           - Show commands for all monitors"
        exit 1
        ;;
esac
