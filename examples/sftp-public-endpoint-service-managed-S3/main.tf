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
  server_name = "transfer-server-${random_pet.name.id}"
  users = fileexists(var.users_file) ? csvdecode(file(var.users_file)) : [] # Read users from CSV
}

data "aws_caller_identity" "current" {}

###################################################################
# Transfer Server example usage
###################################################################
module "transfer_server" {
  source = "../.."
  
  domain                   = "S3"
  protocols                = ["SFTP"]
  endpoint_type            = "PUBLIC"
  server_name              = local.server_name
  dns_provider             = var.dns_provider
  custom_hostname          = var.custom_hostname
  route53_hosted_zone_name = var.route53_hosted_zone_name
  identity_provider        = "SERVICE_MANAGED"
  security_policy_name     = "TransferSecurityPolicy-2024-01" # https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html#security-policy-transfer-2024-01
  enable_logging           = true
  log_retention_days       = 30 # This can be modified based on requirements
  log_group_kms_key_id     = aws_kms_key.transfer_family_key.arn
}

module "sftp_users" {
  source = "../../modules/transfer-users"
  users  = local.users
  create_test_user = true #NOTE: Test user is for demo purposes. Key and Access Management required for the created secrets 

  server_id = module.transfer_server.server_id

  s3_bucket_name = module.s3_bucket.s3_bucket_id
  s3_bucket_arn  = module.s3_bucket.s3_bucket_arn

  kms_key_id = aws_kms_key.transfer_family_key.arn
}

###################################################################
# Create S3 bucket for Transfer Server (Optional if already exists)
###################################################################
module "s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=fc09cc6fb779b262ce1bee5334e85808a107d8a3"
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
        kms_master_key_id = aws_kms_key.transfer_family_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = false # Turn on versioning if needed
  }
}

###################################################################
# Kms key for Transfer Server
###################################################################
resource "aws_kms_key" "transfer_family_key" {
  description             = "KMS key for encrypting S3 bucket and cloudwatch log group"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Transfer and S3 Service"
        Effect = "Allow"
        Principal = {
          Service = [
            "transfer.amazonaws.com",
            "s3.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Transfer Family User Roles"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"        
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/transfer-user-*"
          },
          StringEquals = {
            "aws:PrincipalType": "AssumedRole"
          }
        }
      }
    ]
  })

  tags = {
    Purpose = "Transfer Family Encryption"
  }
}

resource "aws_kms_alias" "transfer_family_key_alias" {
  name          = "alias/transfer-family-key"
  target_key_id = aws_kms_key.transfer_family_key.key_id
}