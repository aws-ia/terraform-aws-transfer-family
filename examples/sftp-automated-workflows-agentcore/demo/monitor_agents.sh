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

# Agent log groups
WORKFLOW="/aws/bedrock-agentcore/runtimes/alnv_workflow_agent-9GGo5c9pDK-alnv_workflow_agent_endpoint"
ENTITY="/aws/bedrock-agentcore/runtimes/eeld_entity_extraction_agent-x2eFhXF84K-eeld_entity_extraction_agent_endpoint"
FRAUD="/aws/bedrock-agentcore/runtimes/dmxj_validation_agent-2LnCup3MaZ-dmxj_validation_agent_endpoint"
DATABASE="/aws/bedrock-agentcore/runtimes/zpkv_database_insertion_agent-UtHw0HEl0k-zpkv_database_insertion_agent_endpoint"
SUMMARY="/aws/bedrock-agentcore/runtimes/ioxo_summary_generation_agent-5TqRkCCQ37-ioxo_summary_generation_agent_endpoint"
CLAIMS_LAMBDA="/aws/lambda/claims-processor-trigger"
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
    "workflow")
        tail_logs "$WORKFLOW" "WORKFLOW" "$MAGENTA"
        ;;
    "entity")
        tail_logs "$ENTITY" "ENTITY" "$BLUE"
        ;;
    "fraud")
        tail_logs "$FRAUD" "FRAUD" "$RED"
        ;;
    "database")
        tail_logs "$DATABASE" "DATABASE" "$YELLOW"
        ;;
    "summary")
        tail_logs "$SUMMARY" "SUMMARY" "$GREEN"
        ;;
    "claims")
        tail_logs "$CLAIMS_LAMBDA" "CLAIMS" "$CYAN"
        ;;
    "malware")
        tail_logs "$MALWARE_LAMBDA" "MALWARE" "$YELLOW"
        ;;
    "all")
        echo -e "${WHITE}Starting all agent monitors...${NC}\n"
        echo -e "${WHITE}Open separate terminals and run:${NC}"
        echo -e "  ${CYAN}Terminal 1:${NC} /tmp/monitor_agents.sh claims"
        echo -e "  ${YELLOW}Terminal 2:${NC} /tmp/monitor_agents.sh malware"
        echo -e "  ${MAGENTA}Terminal 3:${NC} /tmp/monitor_agents.sh workflow"
        echo -e "  ${BLUE}Terminal 4:${NC} /tmp/monitor_agents.sh entity"
        echo -e "  ${RED}Terminal 5:${NC} /tmp/monitor_agents.sh fraud"
        echo -e "  ${YELLOW}Terminal 6:${NC} /tmp/monitor_agents.sh database"
        echo -e "  ${GREEN}Terminal 7:${NC} /tmp/monitor_agents.sh summary"
        ;;
    *)
        echo "Usage: $0 {workflow|entity|fraud|database|summary|claims|malware|all}"
        echo ""
        echo "Agents:"
        echo "  workflow  - Orchestration agent (coordinates all agents)"
        echo "  entity    - Entity extraction agent (reads PDF)"
        echo "  fraud     - Fraud validation agent (compares image to description)"
        echo "  database  - Database insertion agent (saves to DynamoDB)"
        echo "  summary   - Summary generation agent (creates report)"
        echo ""
        echo "Infrastructure:"
        echo "  claims    - Claims processor Lambda (triggers workflow)"
        echo "  malware   - Malware scanner Lambda (GuardDuty integration)"
        echo ""
        echo "  all       - Show commands for all monitors"
        exit 1
        ;;
esac
