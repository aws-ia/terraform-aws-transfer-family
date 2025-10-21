#!/bin/bash

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/../../modules/custom-idps-nizar"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Copy Lambda files from the custom-idps-nizar module
cp "$MODULE_DIR/app.py" .
cp "$MODULE_DIR/cognito.py" .

# Create index.py as entry point
cat > index.py << 'EOF'
from app import handler
EOF

# Create the ZIP file
zip -r lambda.zip *.py

# Move to the example directory
mv lambda.zip "$SCRIPT_DIR/"

# Clean up
rm -rf "$TEMP_DIR"

echo "Lambda package created: lambda.zip"
