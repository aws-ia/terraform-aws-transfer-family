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
  server_name               = "transfer-server-${random_pet.name.id}"
  users                     = fileexists(var.users_file) ? csvdecode(file(var.users_file)) : [] # Read users from CSV
  vpc_id                    = module.vpc.vpc_attributes.id
  public_subnets            = flatten([for _, value in module.vpc.public_subnet_attributes_by_az : [value.id]])
  ingress_cidr_blocks_list  = [for cidr in split(",", var.sftp_ingress_cidr_block) : trimspace(cidr)]
  egress_cidr_blocks_list   = [for cidr in split(",", var.sftp_egress_cidr_block) : trimspace(cidr)]
  az_count                  = 2
}

data "aws_caller_identity" "current" {}

###################################################################
# Transfer Server example usage
###################################################################
module "transfer_server" {
  source = "../.."
  
  domain                   = "S3"
  protocols                = ["SFTP"]
  endpoint_type            = "VPC"
  endpoint_details = {
    address_allocation_ids = aws_eip.sftp[*].allocation_id
    security_group_ids     = [aws_security_group.sftp.id]
    subnet_ids             = local.public_subnets
    vpc_id                 = local.vpc_id
  }
  server_name              = local.server_name
  dns_provider             = var.dns_provider
  custom_hostname          = var.custom_hostname
  route53_hosted_zone_name = var.route53_hosted_zone_name
  identity_provider        = "SERVICE_MANAGED"
  security_policy_name     = "TransferSecurityPolicy-2024-01" # https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html#security-policy-transfer-2024-01
  enable_logging           = true
  log_retention_days       = 30 # This can be modified based on requirements
  log_group_kms_key_id     = aws_kms_key.transfer_family_key.arn
  logging_role             = var.logging_role
  workflow_details         = var.workflow_details 
}

module "sftp_users" {
  source = "../../modules/transfer-users"
  users  = local.users
  create_test_user = true # Test user is for demo purposes. Key and Access Management required for the created secrets 

  server_id = module.transfer_server.server_id

  s3_bucket_name = module.s3_bucket.s3_bucket_id
  s3_bucket_arn  = module.s3_bucket.s3_bucket_arn

  kms_key_id = aws_kms_key.transfer_family_key.arn
}

###################################################################
# Create VPC for Transfer Server
###################################################################
module "vpc" {
  source   = "git::https://github.com/aws-ia/terraform-aws-vpc.git?ref=da49a30fbfeb3890076b783be0abf8639f96f431"

  name                          = "${local.server_name}-vpc"
  cidr_block                    = "10.0.0.0/16"
  az_count                      = local.az_count

  subnets = {
    public = {
      name_prefix               = "${local.server_name}-public-subnet"
      netmask                   = 24
      nat_gateway_configuration = "all_azs" # options: "single_az", "none"
    }
  }
}

resource "aws_eip" "sftp" {
  # checkov:skip=CKV2_AWS_19: EIPs are used for AWS Transfer Family VPC endpoints, not EC2 instances
  count = local.az_count
  tags = {
    Name = "${local.server_name}-sftp-eip-${count.index + 1}"
  }
}

resource "aws_security_group" "sftp" {
  name                    = "${local.server_name}-sftp-sg"
  description             = "Security group for VPC endpoint of AWS Transfer Family SFTP"
  vpc_id                  = local.vpc_id
  revoke_rules_on_delete  = true

  tags = {
    Environment = var.stage
    Name        = "${local.server_name}-sftp-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sftp_ingress" {
  for_each          = toset(local.ingress_cidr_blocks_list)
  security_group_id = aws_security_group.sftp.id
  description       = "Allow inbound SFTP (TCP/22) from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value

  tags = {
    Name = "${local.server_name}-sftp-ingress-${index(local.ingress_cidr_blocks_list, each.value)}"
  }
}

# Separate Egress Rule for SFTP
resource "aws_vpc_security_group_egress_rule" "sftp_egress" {
  for_each          = toset(local.egress_cidr_blocks_list)
  security_group_id = aws_security_group.sftp.id
  description       = "Allow outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = each.value

  tags = {
    Name = "${local.server_name}-sftp-egress-${index(local.egress_cidr_blocks_list, each.value)}"
  }
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
# KMS key and policies for Transfer Server
###################################################################

# KMS Key resource
resource "aws_kms_key" "transfer_family_key" {
  description             = "KMS key for encrypting S3 bucket and cloudwatch log group"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family Encryption"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "transfer_family_key_alias" {
  name          = "alias/transfer-family-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key.key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "transfer_family_key_policy" {
  key_id = aws_kms_key.transfer_family_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Limited Admin Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = aws_kms_key.transfer_family_key.arn
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
      }
    ]
  })
}