locals {
  # Table names - use existing or create new
  users_table_name = var.existing_users_table_name != null ? var.existing_users_table_name : aws_dynamodb_table.users[0].name
  identity_providers_table_name = var.existing_identity_providers_table_name != null ? var.existing_identity_providers_table_name : aws_dynamodb_table.identity_providers[0].name
  
  # Table ARNs
  users_table_arn = var.existing_users_table_name != null ? data.aws_dynamodb_table.existing_users[0].arn : aws_dynamodb_table.users[0].arn
  identity_providers_table_arn = var.existing_identity_providers_table_name != null ? data.aws_dynamodb_table.existing_identity_providers[0].arn : aws_dynamodb_table.identity_providers[0].arn
  
  # Lambda environment variables
  lambda_environment_variables = {
    USERS_TABLE              = local.users_table_name
    IDENTITY_PROVIDERS_TABLE = local.identity_providers_table_name
    USER_NAME_DELIMITER      = var.user_name_delimiter
    LOGLEVEL                = var.log_level
    AWS_XRAY_TRACING_NAME   = var.name_prefix
  }
  
  # VPC configuration
  vpc_config = var.use_vpc ? [{
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }] : []
  
  # Common tags
  common_tags = merge(var.tags, {
    Module    = "terraform-aws-transfer-custom-idp"
    ManagedBy = "Terraform"
  })
}