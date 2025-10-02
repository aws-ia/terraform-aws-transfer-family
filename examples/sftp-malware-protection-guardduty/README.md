# GuardDuty Malware Protection for Existing SFTP Bucket

This example shows how to add GuardDuty malware protection to your existing SFTP S3 bucket without modifying the original deployment.

## Prerequisites

1. Your SFTP server and S3 bucket are already deployed
2. GuardDuty is enabled in your AWS account

## Setup

1. Get your existing bucket name and KMS key ARN:
   ```bash
   # From your sftp-multiple-keys directory
   cd ../sftp-multiple-keys
   terraform output
   ```

2. Update the values in `main.tf`:
   ```hcl
   locals {
     existing_bucket_name = "aws-ia-xyz-s3-sftp"  # Your actual bucket name
     existing_kms_key_arn = "arn:aws:kms:..."     # Your actual KMS key ARN
   }
   ```

3. Deploy GuardDuty protection:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What This Does

- Scans all files uploaded to your SFTP S3 bucket for malware
- Tags infected files with malware scan results
- Uses the same KMS key for encryption compatibility
- Does not modify your existing SFTP setup

## Monitoring

After deployment, malware scan results will appear as S3 object tags. You can view them in the AWS Console or set up EventBridge rules to trigger actions based on scan results.
