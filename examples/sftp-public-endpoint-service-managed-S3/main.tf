#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

######################################
# Defaults and Locals
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

locals {
  domain            = "S3"
  protocols         = ["SFTP"]
  endpoint_type     = "PUBLIC"
  server_name       = "demo-transfer-server-${random_pet.name.id}"
  # dns_provider      = "route53"
  # base_domain       = "souvrard.people.aws.dev"
  # custom_hostname   = "test.sftp.${local.base_domain}"
  identity_provider = "SERVICE_MANAGED"
  create_test_user  = true
  enable_logging = true
  log_retention_days = 14
}

###################################################################
# Create S3 bucket for Transfer Server (Optional if already exists)A
###################################################################
module "s3_bucket" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  version                  = ">=3.5.0"
  bucket                   = lower("${random_pet.name.id}-${module.transfer_server.server_id}-s3-sftp")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.sse_encryption.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = true # Turn off versioning to save costs if this is not necessary for your use-case
  }
}

resource "aws_kms_key" "sse_encryption" {
  description             = "KMS key for encrypting S3 buckets and EBS volumes"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

module "transfer_server" {
  source = "../.."
  
  domain                   = local.domain
  protocols                = local.protocols
  endpoint_type            = local.endpoint_type
  server_name              = local.server_name
  # dns_provider             = local.dns_provider
  # custom_hostname          = local.custom_hostname
  # route53_hosted_zone_name = local.base_domain
  identity_provider        = local.identity_provider
  enable_logging           = local.enable_logging
  log_retention_days       = local.log_retention_days
}

# Read users from CSV
locals {
  users = fileexists(var.users_file) ? csvdecode(file(var.users_file)) : []
}

module "sftp_users" {
  source = "../../modules/transfer-users"
  users  = local.users
  create_test_user = local.create_test_user

  server_id = module.transfer_server.server_id

  s3_bucket_name = module.s3_bucket.s3_bucket_id
  s3_bucket_arn  = module.s3_bucket.s3_bucket_arn

  sse_encryption_arn = aws_kms_key.sse_encryption.arn
}