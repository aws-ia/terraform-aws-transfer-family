#!/bin/bash

################################################################################
# Zip Claims Script
# Creates ZIP files for each claim folder in the data directory
################################################################################

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (parent of code-talk folder)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
OUTPUT_DIR="$DATA_DIR/zipped"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Zipping Claim Folders${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Find all claim folders
CLAIM_FOLDERS=($(find "$DATA_DIR" -maxdepth 1 -type d -name "claim-*" 2>/dev/null))

if [ ${#CLAIM_FOLDERS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No claim folders found in $DATA_DIR${NC}"
    exit 0
fi

echo -e "${YELLOW}Found ${#CLAIM_FOLDERS[@]} claim folder(s)${NC}"
echo ""

# Zip each claim folder
for CLAIM_FOLDER in "${CLAIM_FOLDERS[@]}"; do
    CLAIM_NAME=$(basename "$CLAIM_FOLDER")
    ZIP_FILE="$OUTPUT_DIR/${CLAIM_NAME}.zip"
    
    echo -e "${BLUE}Processing:${NC} $CLAIM_NAME"
    
    # Remove existing ZIP if present
    rm -f "$ZIP_FILE"
    
    # Create ZIP file (cd into folder to avoid including parent path)
    (cd "$CLAIM_FOLDER" && zip -q "$ZIP_FILE" *)
    
    if [ $? -eq 0 ]; then
        ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
        echo -e "${GREEN}✓ Created:${NC} ${CLAIM_NAME}.zip (${ZIP_SIZE})"
        
        # List contents
        echo -e "${BLUE}  Contents:${NC}"
        unzip -l "$ZIP_FILE" | tail -n +4 | head -n -2 | awk '{print "    " $4}'
    else
        echo -e "${RED}✗ Failed to create ZIP for $CLAIM_NAME${NC}"
    fi
    
    echo ""
done

echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}Zipping Complete!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "${BLUE}ZIP files location:${NC} $OUTPUT_DIR"
echo ""
echo -e "You can now upload these ZIP files via SFTP:"
for CLAIM_FOLDER in "${CLAIM_FOLDERS[@]}"; do
    CLAIM_NAME=$(basename "$CLAIM_FOLDER")
    echo -e "  ${GREEN}${CLAIM_NAME}.zip${NC}"
done
echo ""
