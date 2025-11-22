resource "aws_dynamodb_table" "users" {
  count = var.users_table_name == "" ? 1 : 0

  name         = local.users_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "identity_provider_key"

  attribute {
    name = "user"
    type = "S"
  }

  attribute {
    name = "identity_provider_key"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "identity_providers" {
  count = var.identity_providers_table_name == "" ? 1 : 0

  name         = local.providers_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "provider"

  attribute {
    name = "provider"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = local.common_tags
}
