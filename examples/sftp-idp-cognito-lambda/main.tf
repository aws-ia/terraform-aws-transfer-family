terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  
  source {
    content = replace(replace(replace(replace(replace(replace(replace(file("${path.module}/../../modules/custom-idps-nizar/app.py"), 
      "user_record = USERS_TABLE.query(\n            KeyConditionExpression=Key(\"user\").eq(username)\n        ).get(\"Items\", None)",
      "user_record = USERS_TABLE.get_item(Key={\"Username\": username}).get(\"Item\", None)"),
      "user_record = USERS_TABLE.query(\n            KeyConditionExpression=Key(\"user\").eq(\"$default$\")\n        ).get(\"Items\", None)",
      "user_record = None  # No default user support"),
      "user_record = user_record[0]",
      "pass  # user_record is already a single item"),
      "        else:\n            pass  # user_record is already a single item",
      "        # user_record is already a single item, no need for else block"),
      "identity_provider_record = IDENTITY_PROVIDERS_TABLE.get_item(\n        Key={\"provider\": identity_provider}\n    ).get(\"Item\", None)",
      "identity_provider_record = IDENTITY_PROVIDERS_TABLE.get_item(Key={\"ServerId\": event['serverId']}).get(\"Item\", None)"),
      "identity_provider = user_record.get(\"identity_provider_key\", \"$default$\")",
      "identity_provider = \"cognito\"  # Use cognito provider"),
      "server_id",
      "event['serverId']")
    filename = "app.py"
  }
  
  source {
    content = "class Tracer:\n    def capture_method(self, func):\n        return func\n    def capture_lambda_handler(self, func):\n        return func\n    def put_annotation(self, key, value):\n        pass"
    filename = "aws_lambda_powertools/__init__.py"
  }
  
  source {
    content = "import logging\nfrom enum import Enum\nfrom botocore.config import Config\n\nclass AuthenticationMethod(Enum):\n    PASSWORD = 'PASSWORD'\n    PUBLIC_KEY = 'PUBLIC_KEY'\n\nclass IdpModuleError(Exception):\n    pass\n\ndef get_log_level():\n    return logging.INFO\n\nboto3_config = Config(region_name='us-east-1')"
    filename = "idp_modules/util.py"
  }
  
  source {
    content = ""
    filename = "idp_modules/__init__.py"
  }
  
  source {
    content = file("${path.module}/../../modules/custom-idps-nizar/cognito.py")
    filename = "idp_modules/cognito.py"
  }
  
  source {
    content = file("${path.module}/../../modules/custom-idps-nizar/cognito.py")
    filename = "cognito.py"
  }
  
  source {
    content = "from app import lambda_handler as handler"
    filename = "index.py"
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "transfer_users" {
  name = "${var.stack_name}-transfer-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "transfer_client" {
  name         = "${var.stack_name}-transfer-client"
  user_pool_id = aws_cognito_user_pool.transfer_users.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret = false
}

# Test user in Cognito
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = var.test_username

  attributes = {
    email = var.test_email
  }

  temporary_password = var.test_password
  message_action     = "SUPPRESS"
}

resource "aws_cognito_user" "test_user_permanent_password" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = "${var.test_username}-permanent"

  password = var.test_password

  attributes = {
    email = var.test_email
  }
}

# DynamoDB tables
resource "aws_dynamodb_table" "users" {
  name         = "${var.stack_name}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Username"

  attribute {
    name = "Username"
    type = "S"
  }

  tags = var.tags
}

resource "aws_dynamodb_table" "identity_providers" {
  name         = "${var.stack_name}-identity-providers"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ServerId"

  attribute {
    name = "ServerId"
    type = "S"
  }

  tags = var.tags
}

# Custom IDP module
module "custom_idp" {
  source = "../../modules/custom-idps-nizar"

  stack_name                    = var.stack_name
  lambda_zip_path              = data.archive_file.lambda_zip.output_path
  users_table_name             = aws_dynamodb_table.users.name
  identity_providers_table_name = aws_dynamodb_table.identity_providers.name
  use_vpc                      = false
  provision_api                = false  # Don't provision API Gateway for direct Lambda
  enable_tracing               = true

  tags = var.tags
}

# Seed DynamoDB with identity provider config
resource "aws_dynamodb_table_item" "cognito_idp_config" {
  table_name = aws_dynamodb_table.identity_providers.name
  hash_key   = "ServerId"

  item = jsonencode({
    ServerId = {
      S = aws_transfer_server.sftp.id
    }
    provider = {
      S = "cognito"
    }
    module = {
      S = "cognito"
    }
    config = {
      M = {
        cognito_client_id = {
          S = aws_cognito_user_pool_client.transfer_client.id
        }
        cognito_user_pool_region = {
          S = var.aws_region
        }
        mfa = {
          BOOL = false
        }
      }
    }
  })
}

# Seed DynamoDB with test user from Cognito
resource "aws_dynamodb_table_item" "test_user" {
  table_name = aws_dynamodb_table.users.name
  hash_key   = "Username"

  item = jsonencode({
    Username = {
      S = aws_cognito_user.test_user.username
    }
    HomeDirectory = {
      S = "/${aws_s3_bucket.sftp_bucket.bucket}/${aws_cognito_user.test_user.username}"
    }
    Role = {
      S = aws_iam_role.transfer_user_role.arn
    }
    Policy = {
      S = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:ListBucket"
            ]
            Resource = aws_s3_bucket.sftp_bucket.arn
            Condition = {
              StringLike = {
                "s3:prefix" = ["${aws_cognito_user.test_user.username}/*"]
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "${aws_s3_bucket.sftp_bucket.arn}/${aws_cognito_user.test_user.username}/*"
          }
        ]
      })
    }
  })
}

# S3 bucket for SFTP
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = "${var.stack_name}-sftp-${random_id.bucket_suffix.hex}"

  tags = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# IAM role for transfer users
resource "aws_iam_role" "transfer_user_role" {
  name = "${var.stack_name}-transfer-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Transfer server
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "AWS_LAMBDA"
  function              = module.custom_idp.lambda_function_arn
  protocols             = ["SFTP"]
  endpoint_type         = "PUBLIC"

  tags = merge(var.tags, {
    Name = "${var.stack_name}-sftp-server"
  })

  depends_on = [module.custom_idp]
}
