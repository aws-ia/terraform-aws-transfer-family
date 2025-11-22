#!/bin/bash

SERVER="s-a58dd1620ef943f4b.server.transfer.us-east-1.amazonaws.com"
USER="anycompany-repairs"
PASSWORD='iCr05*yfSRPx!{BY'

# Upload files using sftp batch mode
sftp -o StrictHostKeyChecking=no -o PasswordAuthentication=yes <<EOF
$PASSWORD
mkdir claim-3
cd claim-3
put /Users/sekhrip/Documents/Code/transfer-family-poc-reinvent/data/claim-3/car_damage_claim_report.pdf
put /Users/sekhrip/Documents/Code/transfer-family-poc-reinvent/data/claim-3/claim-3.png
bye
EOF

echo "Upload complete!"
