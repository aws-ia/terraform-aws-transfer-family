#!/usr/bin/env bash
#
# view_results.sh — Show agentic claim processing results
#
# Auto-discovers the claims S3 bucket by tag so this works across deployments
# (workshop per-participant accounts, CI dev accounts, etc.) without hardcoding.
#
# Usage:
#   ./view_results.sh                 # list all processed claims
#   ./view_results.sh claim-3         # print a pre-signed URL to summary.html for claim-3
#   ./view_results.sh claim-3 --open  # same + open in the default browser (macOS/Linux)
#   ./view_results.sh claim-3 --raw   # dump the DynamoDB item as JSON
#
# Requirements: aws CLI, jq, a deployed agentic stack in the current account/region.

set -euo pipefail

AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
PRESIGN_EXPIRY="${PRESIGN_EXPIRY:-3600}"  # seconds

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

die() {
  echo -e "${RED}error:${NC} $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "required tool '$1' not found in PATH"
}

need aws
need jq

# ── Resource discovery ───────────────────────────────────────────────────────
# Buckets and tables are tagged with ExampleName = sftp-automated-workflows-agentcore
# by the Terraform stack. We filter on that tag to find the right resources
# without hardcoding names (which vary per deployment).

discover_bucket() {
  # Prefer bucket ending in "-claims-clean" with our example tag.
  local buckets
  buckets=$(aws resourcegroupstaggingapi get-resources \
    --region "$AWS_REGION" \
    --resource-type-filters s3 \
    --tag-filters "Key=ExampleName,Values=sftp-automated-workflows-agentcore" \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text 2>/dev/null | tr '\t' '\n' | awk -F: '{print $NF}' | grep -E 'claims-clean$' || true)

  if [[ -z "$buckets" ]]; then
    # Fallback: look for any bucket with "claims-clean" in the name in this account.
    buckets=$(aws s3api list-buckets \
      --query 'Buckets[?contains(Name, `claims-clean`)].Name' \
      --output text 2>/dev/null || true)
  fi

  local count
  count=$(echo "$buckets" | grep -c . || true)
  if [[ "$count" -eq 0 ]]; then
    die "no claims-clean bucket found in $AWS_REGION — has the stack been deployed?"
  elif [[ "$count" -gt 1 ]]; then
    echo -e "${YELLOW}warning:${NC} multiple claims-clean buckets found, using the first:" >&2
    echo "$buckets" | sed 's/^/  /' >&2
  fi
  echo "$buckets" | head -n1
}

discover_table() {
  local tables
  tables=$(aws dynamodb list-tables --region "$AWS_REGION" \
    --query 'TableNames[?contains(@, `claims`)]' \
    --output text 2>/dev/null | tr '\t' '\n' || true)

  # Prefer tables tagged with our ExampleName.
  local tagged=""
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    local match
    match=$(aws dynamodb list-tags-of-resource \
      --region "$AWS_REGION" \
      --resource-arn "$(aws dynamodb describe-table --region "$AWS_REGION" --table-name "$t" --query 'Table.TableArn' --output text)" \
      --query "Tags[?Key=='ExampleName' && Value=='sftp-automated-workflows-agentcore'].Value" \
      --output text 2>/dev/null || true)
    if [[ -n "$match" ]]; then
      tagged="$t"
      break
    fi
  done <<< "$tables"

  if [[ -n "$tagged" ]]; then
    echo "$tagged"
    return
  fi

  # Fallback: first table matching "claims" heuristic.
  local first
  first=$(echo "$tables" | head -n1)
  [[ -z "$first" ]] && die "no claims DynamoDB table found in $AWS_REGION"
  echo "$first"
}

# ── Commands ─────────────────────────────────────────────────────────────────

list_claims() {
  local table bucket
  table=$(discover_table)
  bucket=$(discover_bucket)

  echo -e "${CYAN}Claims table:${NC} $table"
  echo -e "${CYAN}Claims bucket:${NC} $bucket"
  echo ""

  local items
  items=$(aws dynamodb scan \
    --region "$AWS_REGION" \
    --table-name "$table" \
    --projection-expression "claim_id, #s, updated_at, summary_s3_key" \
    --expression-attribute-names '{"#s":"status"}' \
    --output json 2>/dev/null || echo '{"Items":[]}')

  local count
  count=$(echo "$items" | jq '.Items | length')
  if [[ "$count" -eq 0 ]]; then
    echo -e "${YELLOW}No claims processed yet.${NC}"
    echo "Upload a claim ZIP to s3://$bucket/ to trigger processing."
    return
  fi

  echo -e "${CYAN}Claims (${count}):${NC}"
  echo "$items" | jq -r '
    .Items | sort_by(.updated_at.S // "") | reverse | .[] |
    "  \(.claim_id.S // "?")\t\(.status.S // "unknown")\t\(.updated_at.S // "")\t\(.summary_s3_key.S // "(no summary)")"
  ' | column -t -s $'\t' -N "CLAIM,STATUS,UPDATED,SUMMARY KEY" | sed 's/^/  /'
}

show_claim() {
  local claim_id=$1
  local mode=${2:-url}  # url | open | raw

  local table bucket
  table=$(discover_table)
  bucket=$(discover_bucket)

  if [[ "$mode" == "raw" ]]; then
    aws dynamodb get-item \
      --region "$AWS_REGION" \
      --table-name "$table" \
      --key "{\"claim_id\":{\"S\":\"$claim_id\"}}" \
      --output json | jq '.Item // "claim not found"'
    return
  fi

  # Look up the stored summary_s3_key; fall back to the conventional path.
  local key
  key=$(aws dynamodb get-item \
    --region "$AWS_REGION" \
    --table-name "$table" \
    --key "{\"claim_id\":{\"S\":\"$claim_id\"}}" \
    --query 'Item.summary_s3_key.S' \
    --output text 2>/dev/null || echo "None")

  if [[ "$key" == "None" || -z "$key" ]]; then
    key="$claim_id/summary.html"
  fi

  # Verify object exists before presigning.
  if ! aws s3api head-object --bucket "$bucket" --key "$key" --region "$AWS_REGION" >/dev/null 2>&1; then
    die "summary not found at s3://$bucket/$key — has the pipeline completed for $claim_id?"
  fi

  local url
  url=$(aws s3 presign "s3://$bucket/$key" --region "$AWS_REGION" --expires-in "$PRESIGN_EXPIRY")

  echo -e "${GREEN}Summary ready:${NC} s3://$bucket/$key"
  echo -e "${CYAN}Pre-signed URL (expires in ${PRESIGN_EXPIRY}s):${NC}"
  echo ""
  echo "  $url"
  echo ""

  if [[ "$mode" == "open" ]]; then
    if command -v open >/dev/null 2>&1; then
      open "$url"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$url"
    else
      echo -e "${YELLOW}warning:${NC} no 'open' or 'xdg-open' found — paste the URL in a browser manually." >&2
    fi
  fi
}

# ── Argument parsing ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  list_claims
  exit 0
fi

claim_id=""
mode="url"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --open) mode="open"; shift ;;
    --raw)  mode="raw";  shift ;;
    -h|--help)
      sed -n '1,20p' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$claim_id" ]]; then
        claim_id="$1"
      else
        die "unexpected argument: $1"
      fi
      shift
      ;;
  esac
done

[[ -z "$claim_id" ]] && die "missing claim_id (e.g. ./view_results.sh claim-3)"
show_claim "$claim_id" "$mode"
