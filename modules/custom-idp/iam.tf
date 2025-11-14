# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "${var.stack_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# VPC execution policy (if using VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.use_vpc ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# DynamoDB access policy
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.stack_name}-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.identity_providers_table_name}"
        ]
      }
    ]
  })
}

# Secrets Manager access (if enabled)
resource "aws_iam_role_policy" "secrets_manager" {
  count = var.secrets_manager_permissions ? 1 : 0
  name  = "${var.stack_name}-secrets-policy"
  role  = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# API Gateway Lambda execution policy (when using API Gateway)
resource "aws_iam_role_policy_attachment" "lambda_api_gateway" {
  count      = var.use_api_gateway ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
  role       = aws_iam_role.lambda_role.name
}

# Cognito access policy
resource "aws_iam_role_policy" "cognito_access" {
  name = "${var.stack_name}-cognito-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminListGroupsForUser"
        ]
        Resource = aws_cognito_user_pool.sftp_users.arn
      }
    ]
  })
}

# Transfer Family invocation role (for direct Lambda)
resource "aws_iam_role" "transfer_invocation_role" {
  count = var.use_api_gateway ? 0 : 1
  name = "${var.stack_name}-transfer-invocation-role"

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

resource "aws_iam_role_policy" "transfer_invoke_lambda" {
  count = var.use_api_gateway ? 0 : 1
  name = "${var.stack_name}-transfer-invoke-policy"
  role = aws_iam_role.transfer_invocation_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.identity_provider.arn
      }
    ]
  })
}

# Transfer Family invocation role (for API Gateway)
resource "aws_iam_role" "transfer_api_gateway_role" {
  count = var.use_api_gateway ? 1 : 0
  name  = "${var.stack_name}-transfer-api-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "transfer_api_gateway_policy" {
  count = var.use_api_gateway ? 1 : 0
  name  = "${var.stack_name}-transfer-api-gateway-policy"
  role  = aws_iam_role.transfer_api_gateway_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "execute-api:Invoke"
      Resource = "${aws_api_gateway_rest_api.identity_provider[0].execution_arn}/*/*"
    }]
  })
}
