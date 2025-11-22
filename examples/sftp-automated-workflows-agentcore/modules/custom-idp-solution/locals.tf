locals {
  # Resource naming
  function_name     = "${var.name_prefix}-handler"
  layer_name        = "${var.name_prefix}-layer"
  users_table       = var.users_table_name != "" ? var.users_table_name : "${var.name_prefix}_users"
  providers_table   = var.identity_providers_table_name != "" ? var.identity_providers_table_name : "${var.name_prefix}_identity_providers"
  codebuild_project = "${var.name_prefix}-build"
  artifacts_bucket  = "${var.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"

  # Artifact keys
  function_artifact_key = "lambda-function.zip"
  layer_artifact_key    = "lambda-layer.zip"

  # VPC configuration
  use_vpc_config = var.use_vpc && (var.create_vpc || length(var.subnet_ids) > 0)

  vpc_config = local.use_vpc_config ? {
    subnet_ids         = var.create_vpc ? aws_subnet.private[*].id : var.subnet_ids
    security_group_ids = var.create_vpc ? [aws_security_group.lambda[0].id] : var.security_group_ids
  } : null

  # Common tags
  common_tags = merge(
    var.tags,
    {
      Module    = "terraform-aws-transfer-custom-idp"
      ManagedBy = "Terraform"
    }
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
