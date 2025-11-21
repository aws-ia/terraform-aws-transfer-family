provider "aws" {
  region = var.aws_region
}

######################################
# Defaults and Locals
######################################

data "aws_caller_identity" "current" {}

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

locals {
  server_name = "transfer-server-${random_pet.name.id}"
}

###################################################################
# Custom IDP module
###################################################################
#checkov:skip=CKV_AWS_119:Using AWS managed encryption is acceptable for this example
#checkov:skip=CKV_AWS_147:Using AWS managed encryption is acceptable for this example
#checkov:skip=CKV_AWS_116:DLQ not required for synchronous IdP authentication flow
#checkov:skip=CKV_AWS_173:Using AWS managed encryption is acceptable for this example
#checkov:skip=CKV_AWS_272:Code signing adds operational complexity without significant security benefit
#checkov:skip=CKV_AWS_115:Concurrent execution limit not required, AWS manages throttling
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix                     = var.name_prefix
  users_table_name                = ""
  identity_providers_table_name   = ""
  create_vpc                      = false
  use_vpc                         = false
  provision_api                   = false
  
  tags = var.tags
}

###################################################################
# Transfer Server example usage
###################################################################
module "transfer_server" {
  source = "../.."
  
  domain                   = "S3"
  protocols                = ["SFTP"]
  endpoint_type            = "PUBLIC"
  server_name              = local.server_name
  identity_provider        = "AWS_LAMBDA"
  lambda_function_arn      = module.custom_idp.lambda_function_arn
  security_policy_name     = "TransferSecurityPolicy-2024-01" # https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html#security-policy-transfer-2024-01
  enable_logging           = true

}
