# Existing DynamoDB tables (if specified)
data "aws_dynamodb_table" "existing_users" {
  count = var.existing_users_table_name != null ? 1 : 0
  name  = var.existing_users_table_name
}

data "aws_dynamodb_table" "existing_identity_providers" {
  count = var.existing_identity_providers_table_name != null ? 1 : 0
  name  = var.existing_identity_providers_table_name
}

# Current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC information (if VPC is used)
data "aws_vpc" "selected" {
  count = var.use_vpc && var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnets" "selected" {
  count = var.use_vpc && var.vpc_id != null && length(var.subnet_ids) > 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.subnet_ids
  }
}

# Security group information (if VPC is used)
data "aws_security_groups" "selected" {
  count = var.use_vpc && var.vpc_id != null && length(var.security_group_ids) > 0 ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "group-id"
    values = var.security_group_ids
  }
}