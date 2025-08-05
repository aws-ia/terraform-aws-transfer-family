#!/bin/bash

# SFTP Host Key Discovery Script
# This script discovers SSH host keys from a remote SFTP server
# Usage: 
#   1. Command line: ./discover_host_keys.sh <sftp_server_url> <connector_id>
#   2. JSON stdin: echo '{"sftp_server_url": "sftp://example.com:22", "connector_id": "test"}' | ./discover_host_keys.sh

set -e

# Function to log messages (only in non-Terraform mode)
log_message() {
    if [ "$TERRAFORM_MODE" != "true" ]; then
        echo "$1"
    fi
}

# Function to discover host keys
discover_host_keys() {
    local SFTP_SERVER_URL="$1"
    local CONNECTOR_ID="$2"
    
    log_message "Discovering host keys for URL: ${SFTP_SERVER_URL}"

    # Wait for the Transfer server to be fully ready
    log_message "Waiting 30 seconds for Transfer server to be fully operational..."
    sleep 30

    # Extract hostname and port from URL
    URL="${SFTP_SERVER_URL}"
    # Remove sftp:// prefix
    URL_WITHOUT_PROTOCOL=${URL#sftp://}
    # Extract hostname (everything before the first colon, if any)
    HOSTNAME=${URL_WITHOUT_PROTOCOL%%:*}
    # Extract port (everything after the first colon, if any)
    if [[ "${URL_WITHOUT_PROTOCOL}" == *":"* ]]; then
      PORT=${URL_WITHOUT_PROTOCOL#*:}
      # Remove any path after the port
      PORT=${PORT%%/*}
    else
      PORT=22
    fi

    log_message "Using hostname: ${HOSTNAME}, port: ${PORT}"

    # Use ssh-keyscan to discover host keys with retry logic
    log_message "Running ssh-keyscan with retry logic..."

    HOST_KEY=""

    # Try 5 times with 10 second intervals
    for attempt in 1 2 3 4 5; do
      log_message "Attempt ${attempt}/5: Scanning for host keys..."
      
      # Try to get any SSH host key (rsa, ed25519, ecdsa) - exclude comment lines
      HOST_KEY=$(ssh-keyscan -p ${PORT} ${HOSTNAME} 2>/dev/null | grep -v '^#' | head -n 1)
      
      if [ -z "${HOST_KEY}" ]; then
        log_message "No host key found on attempt ${attempt}, waiting 10 seconds..."
        if [ ${attempt} -lt 5 ]; then
          sleep 10
        fi
      else
        log_message "Host key discovered on attempt ${attempt}"
        break
      fi
    done

    if [ ! -z "${HOST_KEY}" ]; then
      log_message "Discovered host key: ${HOST_KEY}"
      echo "${HOST_KEY}" > /tmp/discovered-keys-${CONNECTOR_ID}.txt
      log_message "Host key saved to: /tmp/discovered-keys-${CONNECTOR_ID}.txt"
      
      # Check if we're being called from Terraform (JSON output expected)
      if [ "$TERRAFORM_MODE" = "true" ]; then
        # Output ONLY JSON for Terraform - no other messages
        # Note: Terraform external data source requires all values to be strings, not arrays
        echo "{\"host_key\": \"${HOST_KEY}\", \"key_count\": \"1\", \"sftp_server_url\": \"${SFTP_SERVER_URL}\", \"connector_id\": \"${CONNECTOR_ID}\"}"
      else
        # Also output the key in a format that can be used in Terraform
        echo ""
        echo "=== For Terraform Configuration ==="
        echo "trusted_host_keys = ["
        echo "  \"${HOST_KEY}\""
        echo "]"
        echo "=================================="
      fi
      
      exit 0
    else
      log_message "Failed to discover host key after 5 attempts"
      log_message "This might be due to:"
      log_message "1. Network connectivity issues"
      log_message "2. SFTP server not ready yet"
      log_message "3. Firewall blocking SSH connections"
      log_message "4. Server not accepting SSH connections on port ${PORT}"
      log_message ""
      log_message "You can manually provide host keys using the trusted_host_keys variable"
      touch /tmp/discovered-keys-${CONNECTOR_ID}.txt
      
      if [ "$TERRAFORM_MODE" = "true" ]; then
        # Output JSON error for Terraform
        echo "{\"error\": \"Failed to discover host key after 5 attempts\"}" >&2
      fi
      
      exit 1
    fi
}

# Main execution
if [ $# -eq 2 ]; then
    # Command line arguments provided
    SFTP_SERVER_URL="$1"
    CONNECTOR_ID="$2"
    discover_host_keys "$SFTP_SERVER_URL" "$CONNECTOR_ID"
elif [ $# -eq 0 ]; then
    # No arguments, try to read from stdin (Terraform mode)
    export TERRAFORM_MODE=true
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "{\"error\": \"jq command not found\"}" >&2
        exit 1
    fi
    
    # Read input JSON from stdin
    eval "$(jq -r '@sh "SFTP_SERVER_URL=\(.sftp_server_url) CONNECTOR_ID=\(.connector_id)"')"
    
    if [ -z "$SFTP_SERVER_URL" ] || [ -z "$CONNECTOR_ID" ]; then
        echo "{\"error\": \"Invalid or missing sftp_server_url or connector_id in JSON input\"}" >&2
        exit 1
    fi
    
    discover_host_keys "$SFTP_SERVER_URL" "$CONNECTOR_ID"
else
    echo "Usage: $0 <sftp_server_url> <connector_id>"
    echo "   OR: echo '{\"sftp_server_url\": \"sftp://example.com:22\", \"connector_id\": \"test\"}' | $0"
    echo "Example: $0 sftp://example.com:22 c-1234567890abcdef0"
    exit 1
fi
