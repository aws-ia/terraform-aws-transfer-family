#!/bin/bash

# Mask AWS account IDs in all output (set SHOW_ACCOUNT_IDS=1 to disable)
source "$(dirname "${BASH_SOURCE[0]}")/mask-account-ids.sh"

################################################################################
# Demo Preflight
# Checks, before going on stage:
#   1. iPad: ACME AirPlay on + iPad connected as a Sidecar display
#      (turned on automatically if it is not)
#   2. The claim buckets and the claims table are reset (no claim-* left over).
#      If not, it asks once [y/N] and deletes the leftover objects and records.
#   3. The local seed files (data/claim-N, data/zipped) are in place
# Exits 1 if any check fails.
#
# Usage: ./demo-preflight.sh
# Stack resources are kept (cleanup.sh is the one that destroys them).
# The iPad check runs the ChalkBoard repo's scripts/sidecar.sh check
# (override the path with SIDECAR_SH=/path/to/sidecar.sh).
################################################################################

export AWS_PAGER=""

AWS_TIMEOUTS="--cli-connect-timeout 5 --cli-read-timeout 15"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
GREY='\033[0;90m'
NC='\033[0m'
if [ -n "${NO_COLOR:-}" ]; then RED=; GREEN=; YELLOW=; BLUE=; CYAN=; GREY=; NC=; fi

# Example root (two levels above the scripts folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="$SCRIPT_DIR/data"

FAILED=0
FIXES=""

pass()   { echo -e "${GREEN}✓${NC} $1"; }
fail()   { echo -e "${RED}✗${NC} $1"; FAILED=$((FAILED + 1)); }
warn()   { echo -e "${YELLOW}⚠${NC} $1"; }
detail() { echo -e "  ${GREY}$1${NC}"; }
add_fix() { FIXES="${FIXES}  $1\n"; }
section() { echo ""; echo -e "${BLUE}── $1 ──${NC}"; }

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Demo Preflight${NC}"
echo -e "${BLUE}=================================${NC}"

################################################################################
# 1. iPad Sidecar display
################################################################################
section "iPad Sidecar display"

SIDECAR_SH="${SIDECAR_SH:-$HOME/Documents/Code/ChalkBoard/scripts/sidecar.sh}"
if [ -x "$SIDECAR_SH" ]; then
    SIDECAR_OUT=$("$SIDECAR_SH" check 2>&1)
    SIDECAR_RC=$?
    # Show its ✓/✗ lines; its own "To fix" line is folded into the summary below.
    echo "$SIDECAR_OUT" | grep -v "To fix:" | grep -v "^Building sidecar helper"
    if [ $SIDECAR_RC -ne 0 ]; then
        echo -e "${YELLOW}→${NC} Not enabled. Turning it on..."
        "$SIDECAR_SH" on 2>&1 | grep -v "^Building sidecar helper" | while IFS= read -r l; do detail "$l"; done
        SIDECAR_OUT=$("$SIDECAR_SH" check 2>&1)
        SIDECAR_RC=$?
        echo "$SIDECAR_OUT" | grep -v "To fix:" | grep -v "^Building sidecar helper"
    fi
    if [ $SIDECAR_RC -ne 0 ]; then
        FAILED=$((FAILED + 1))
        add_fix "iPad: unlock it (nearby, Wi-Fi + Bluetooth on), then: $SIDECAR_SH on"
    fi
else
    fail "iPad check not run: $SIDECAR_SH not found"
    add_fix "iPad: set SIDECAR_SH=/path/to/ChalkBoard/scripts/sidecar.sh"
fi

################################################################################
# 2. Buckets and claims table reset
################################################################################
section "Claim buckets and table"

tf_out() { terraform -chdir="$SCRIPT_DIR" output -raw "$1" 2>/dev/null; }

# Account and region the stack was deployed to, taken from an ARN in the outputs.
STACK_ARN=$(tf_out cognito_password_secret_arn)
[ -z "$STACK_ARN" ] && STACK_ARN=$(tf_out agentcore_document_extraction_agent_arn)
STACK_REGION=$(echo "$STACK_ARN" | cut -d: -f4)
STACK_ACCOUNT=$(echo "$STACK_ARN" | cut -d: -f5)
[ -n "$STACK_REGION" ] && AWS_TIMEOUTS="$AWS_TIMEOUTS --region $STACK_REGION"

CACHE_DIR="$HOME/.cache/demo-preflight"
PROBE_SECS=20

# Prints "<account>\t<arn>" for the given profile ("" = whatever is loaded now).
# Capped at PROBE_SECS so a profile that wants an interactive login can't hang.
caller_of() {
    if [ -n "$1" ]; then
        env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
            perl -e 'alarm shift; exec @ARGV' "$PROBE_SECS" \
            aws sts get-caller-identity $AWS_TIMEOUTS --profile "$1" --query '[Account, Arn]' --output text 2>&1 </dev/null
    else
        perl -e 'alarm shift; exec @ARGV' "$PROBE_SECS" \
            aws sts get-caller-identity $AWS_TIMEOUTS --query '[Account, Arn]' --output text 2>&1 </dev/null
    fi
}

# Profile names from the shared config/credentials files (works with AWS CLI v1 and v2).
list_profiles() {
    {
        sed -n 's/^\[profile[[:space:]]*\([^]]*\)\].*/\1/p' "${AWS_CONFIG_FILE:-$HOME/.aws/config}" 2>/dev/null
        sed -n 's/^\[\([^]]*\)\].*/\1/p' "${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}" 2>/dev/null
        grep -q '^\[default\]' "${AWS_CONFIG_FILE:-$HOME/.aws/config}" 2>/dev/null && echo default
    } | sed 's/[[:space:]]*$//'
}

# Switches this run (and every aws command after it) to the given profile.
use_profile() {
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    export AWS_PROFILE="$1"
    mkdir -p "$CACHE_DIR" && echo "$1" >"$CACHE_DIR/profile-$STACK_ACCOUNT"
}

AWS_OK=true
if ! command -v aws >/dev/null 2>&1; then
    fail "AWS CLI not found"
    AWS_OK=false
else
    # 1. Whatever is loaded now (env vars, AWS_PROFILE or [default]).
    LOADED_DESC="${AWS_PROFILE:+profile $AWS_PROFILE}"
    [ -n "$AWS_ACCESS_KEY_ID" ] && LOADED_DESC="environment variables"
    LOADED_DESC="${LOADED_DESC:-default profile}"
    CALLER=$(caller_of "")
    LOADED_RC=$?
    CALLER_ACCOUNT=$(echo "$CALLER" | cut -f1)
    CALLER_ARN=$(echo "$CALLER" | cut -f2)
    CRED_SOURCE="$LOADED_DESC"

    if [ -n "$STACK_ACCOUNT" ] && { [ $LOADED_RC -ne 0 ] || [ "$CALLER_ACCOUNT" != "$STACK_ACCOUNT" ]; }; then
        if [ $LOADED_RC -ne 0 ]; then
            detail "Loaded credentials ($LOADED_DESC) are not usable: $(echo "$CALLER" | grep -v '^$' | tail -1)"
        else
            detail "Loaded credentials ($LOADED_DESC) are for account …${CALLER_ACCOUNT: -4}, not the stack's …${STACK_ACCOUNT: -4}"
        fi

        # 2. The profile that matched last time, then every other configured profile.
        CACHED=$(cat "$CACHE_DIR/profile-$STACK_ACCOUNT" 2>/dev/null)
        CANDIDATES=$( { [ -n "$CACHED" ] && echo "$CACHED"; list_profiles; } \
            | awk 'NF && !seen[$0]++' | grep -v -x -F "${AWS_PROFILE:-<none>}")
        FOUND=""
        if [ -n "$CANDIDATES" ]; then
            TOTAL=$(echo "$CANDIDATES" | wc -l | tr -d ' ')
            N=0
            while IFS= read -r prof; do
                N=$((N + 1))
                printf '  %bChecking profile %d/%d: %s%b\033[K\r' "$GREY" "$N" "$TOTAL" "$prof" "$NC"
                OUT=$(caller_of "$prof") || continue
                if [ "$(echo "$OUT" | cut -f1)" = "$STACK_ACCOUNT" ]; then
                    FOUND="$prof"
                    CALLER_ACCOUNT=$(echo "$OUT" | cut -f1)
                    CALLER_ARN=$(echo "$OUT" | cut -f2)
                    break
                fi
            done <<<"$CANDIDATES"
            printf '\033[K'
        fi

        if [ -n "$FOUND" ]; then
            use_profile "$FOUND"
            CRED_SOURCE="profile $FOUND (auto-picked)"
        else
            fail "No AWS profile has working credentials for the stack's account (…${STACK_ACCOUNT: -4})"
            add_fix "AWS: sign in to account …${STACK_ACCOUNT: -4} (or add a profile for it), then re-run this script"
            AWS_OK=false
        fi
    elif [ $LOADED_RC -ne 0 ]; then
        fail "AWS credentials are not usable ($LOADED_DESC)"
        detail "$(echo "$CALLER" | grep -v '^$' | tail -1)"
        add_fix "AWS: refresh credentials, then re-run this script"
        AWS_OK=false
    fi

    if [ "$AWS_OK" = true ]; then
        pass "AWS credentials OK: $CRED_SOURCE (account …${CALLER_ACCOUNT: -4}, ${STACK_REGION:-default region})"
        detail "$CALLER_ARN"
    fi
fi

GD_OBJECT='malware-protection-resource-validation-object'
DIRTY_BUCKETS=""
DIRTY_CLAIMS=""

# Lists what is left in each bucket and in the claims table.
# Fills DIRTY_BUCKETS (space-separated) and DIRTY_CLAIMS (one claim_id per line).
check_claim_data() {
    DIRTY_BUCKETS=""
    DIRTY_CLAIMS=""
    TRANSFER_BUCKET=$(tf_out transfer_s3_bucket_name)
    UPLOAD_BUCKET=$(tf_out malware_upload_bucket_name)
    CLEAN_BUCKET=$(tf_out malware_clean_bucket_name)
    QUARANTINE_BUCKET=$(tf_out malware_quarantine_bucket_name)
    ERRORS_BUCKET=$(tf_out malware_errors_bucket_name)
    CLAIMS_TABLE=$(tf_out agentcore_claims_table_name)

    if [ -z "$TRANSFER_BUCKET$UPLOAD_BUCKET$CLEAN_BUCKET" ]; then
        fail "No bucket names in Terraform outputs (is the stack deployed?)"
    fi

    # Check each distinct bucket once (the transfer and upload buckets can be the same).
    SEEN=" "
    for entry in \
        "Transfer|$TRANSFER_BUCKET" \
        "Upload|$UPLOAD_BUCKET" \
        "Clean|$CLEAN_BUCKET" \
        "Quarantine|$QUARANTINE_BUCKET" \
        "Errors|$ERRORS_BUCKET"; do
        label=${entry%%|*}
        bucket=${entry#*|}
        [ -z "$bucket" ] && continue
        case "$SEEN" in *" $bucket "*) continue ;; esac
        SEEN="$SEEN$bucket "

        KEYS=$(aws s3api list-objects-v2 $AWS_TIMEOUTS --bucket "$bucket" \
            --query 'Contents[].Key' --output text 2>&1)
        if [ $? -ne 0 ]; then
            fail "$label bucket: could not list $bucket"
            detail "$(echo "$KEYS" | grep -v '^$' | tail -1)"
            continue
        fi
        [ "$KEYS" = "None" ] && KEYS=""
        # GuardDuty Malware Protection writes its own validation object; it is not demo data.
        KEYS=$(echo "$KEYS" | tr '\t' '\n' | grep -v '^$' | grep -v -x "$GD_OBJECT")

        if [ -z "$KEYS" ]; then
            pass "$label bucket is empty ($bucket)"
            continue
        fi

        TOTAL=$(echo "$KEYS" | wc -l | tr -d ' ')
        # Group leftovers: claim-N/ folders, claim-N.zip files, everything else.
        SUMMARY=$(echo "$KEYS" | awk '
            {
                n = split($0, p, "/"); hit = ""
                for (i = 1; i <= n; i++) {
                    if (p[i] ~ /^claim-[^\/]*\.zip$/) { hit = $0; break }
                    if (p[i] ~ /^claim-/ && i < n)    { hit = ""; for (j = 1; j <= i; j++) hit = hit p[j] "/"; break }
                }
                if (hit == "") hit = "(other) " $0
                c[hit]++
            }
            END { for (k in c) printf "%s|%d\n", k, c[k] }' | sort)

        fail "$label bucket is not reset: $TOTAL object(s) in $bucket"
        echo "$SUMMARY" | while IFS='|' read -r what count; do
            if [ "$count" -gt 1 ]; then detail "$what ($count files)"; else detail "$what"; fi
        done
        DIRTY_BUCKETS="$DIRTY_BUCKETS $bucket"
        add_fix "Reset: re-run ./demo-preflight.sh and answer y"
    done

    # Claims table: any record shows up in the web app as an old claim.
    if [ -n "$CLAIMS_TABLE" ]; then
        ITEMS=$(aws dynamodb scan $AWS_TIMEOUTS --table-name "$CLAIMS_TABLE" \
            --query 'Items[].[claim_id.S, status.S]' --output text 2>&1)
        if [ $? -ne 0 ]; then
            fail "Claims table: could not scan $CLAIMS_TABLE"
            detail "$(echo "$ITEMS" | grep -v '^$' | tail -1)"
        else
            ITEMS=$(echo "$ITEMS" | grep -v '^$' | grep -v '^None$')
            if [ -z "$ITEMS" ]; then
                pass "Claims table is empty ($CLAIMS_TABLE)"
            else
                COUNT=$(echo "$ITEMS" | wc -l | tr -d ' ')
                fail "Claims table is not reset: $COUNT record(s) in $CLAIMS_TABLE"
                while IFS=$'\t' read -r cid status; do
                    detail "$cid (${status:-no status})"
                    DIRTY_CLAIMS="$DIRTY_CLAIMS$cid
"
                done <<<"$(echo "$ITEMS" | sort)"
                add_fix "Reset: re-run ./demo-preflight.sh and answer y"
            fi
        fi
    else
        warn "No claims table in Terraform outputs (Stage 3 not deployed?)"
    fi
}

# Deletes the leftovers found by check_claim_data (current objects only; the
# GuardDuty validation object and the buckets/table themselves are kept).
reset_claim_data() {
    local do_buckets=true do_table=true
    [ -z "$DIRTY_BUCKETS" ] && do_buckets=false
    [ -z "$DIRTY_CLAIMS" ] && do_table=false
    [ "$do_buckets" = false ] && [ "$do_table" = false ] && return 1
    # Only ask when someone is at the keyboard; otherwise just report.
    { [ -t 0 ] && [ -r /dev/tty ]; } || return 1

    section "Reset"
    [ "$do_buckets" = true ] && for b in $DIRTY_BUCKETS; do echo "  Empty s3://$b"; done
    [ "$do_table" = true ] && echo "  Delete $(echo "$DIRTY_CLAIMS" | grep -c .) record(s) from $CLAIMS_TABLE"
    printf '%b' "${YELLOW}Delete these? This cannot be undone. [y/N] ${NC}"
    read -r answer </dev/tty
    case "$answer" in y|Y|yes|YES) ;; *) echo "Kept."; return 1 ;; esac

    if [ "$do_buckets" = true ]; then
        for b in $DIRTY_BUCKETS; do
            if OUT=$(aws s3 rm $AWS_TIMEOUTS "s3://$b" --recursive --exclude "$GD_OBJECT" --only-show-errors 2>&1); then
                pass "Emptied s3://$b"
            else
                fail "Could not empty s3://$b"
                detail "$(echo "$OUT" | grep -v '^$' | tail -1)"
            fi
        done
    fi
    if [ "$do_table" = true ]; then
        while IFS= read -r cid; do
            [ -z "$cid" ] && continue
            if OUT=$(aws dynamodb delete-item $AWS_TIMEOUTS --table-name "$CLAIMS_TABLE" \
                    --key "{\"claim_id\":{\"S\":\"$cid\"}}" 2>&1); then
                pass "Deleted $cid from $CLAIMS_TABLE"
            else
                fail "Could not delete $cid from $CLAIMS_TABLE"
                detail "$(echo "$OUT" | grep -v '^$' | tail -1)"
            fi
        done <<<"$DIRTY_CLAIMS"
    fi
    return 0
}

if [ "$AWS_OK" = true ]; then
    FAILED_BEFORE=$FAILED
    FIXES_BEFORE=$FIXES
    check_claim_data
    if [ -n "$DIRTY_BUCKETS$DIRTY_CLAIMS" ]; then
        RESET_FAILED_BEFORE=$FAILED
        if reset_claim_data; then
            # Re-check from scratch so the summary reflects the state after the reset.
            RESET_ERRORS=$((FAILED - RESET_FAILED_BEFORE))
            FAILED=$((FAILED_BEFORE + RESET_ERRORS))
            FIXES=$FIXES_BEFORE
            section "Claim buckets and table (after reset)"
            check_claim_data
        fi
    fi
fi

################################################################################
# 3. Local seed files
################################################################################
section "Local seed files (data/)"

SEED_DIRS=$(find "$DATA_DIR" -maxdepth 1 -type d -name 'claim-*' 2>/dev/null | sort)
if [ -z "$SEED_DIRS" ]; then
    fail "No claim folders in $DATA_DIR"
else
    for dir in $SEED_DIRS; do
        name=$(basename "$dir")
        files=$(find "$dir" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d ' ')
        zip="$DATA_DIR/zipped/$name.zip"
        if [ "$files" -lt 4 ]; then
            fail "$name: $files file(s), expected 4 (photo, policy, estimate, submission form)"
        elif [ ! -f "$zip" ]; then
            fail "$name: zipped/$name.zip is missing"
            add_fix "Zips: ./zip-claims.sh"
        elif [ -n "$(find "$dir" -maxdepth 1 -type f -newer "$zip" ! -name '.*')" ]; then
            warn "$name: folder changed after zipped/$name.zip was built"
            add_fix "Zips: ./zip-claims.sh"
        else
            pass "$name: $files files, zip up to date"
        fi
    done
fi

################################################################################
# Summary
################################################################################
echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}Ready: all checks passed.${NC}"
    if [ -n "$FIXES" ]; then
        echo -e "${YELLOW}Optional:${NC}"
        echo -e "$FIXES" | awk 'NF && !seen[$0]++'
    fi
    exit 0
fi

echo -e "${RED}Not ready: $FAILED check(s) failed.${NC}"
echo -e "${YELLOW}To fix:${NC}"
echo -e "$FIXES" | awk 'NF && !seen[$0]++' | while IFS= read -r line; do
    echo -e "${CYAN}${line}${NC}"
done
exit 1
