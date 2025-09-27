# Deploy GuardDuty malware protection for your existing SFTP S3 bucket

locals {
  existing_bucket_name = ""
  existing_kms_key_arn = ""
}

module "guardduty_malware_protection" {
  source = "../../modules/guardduty-malware-protection"
  
  name_prefix     = "sftp-malware-protection"
  s3_bucket_name  = local.existing_bucket_name
  kms_key_arn     = local.existing_kms_key_arn
  
  # Scan all objects
  object_prefixes = []
  
  tags = {
    Environment = "Production"
    Purpose     = "SFTP Malware Protection"
  }
}
