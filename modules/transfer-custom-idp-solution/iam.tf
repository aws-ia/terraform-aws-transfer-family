# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"

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

# DynamoDB access policy (read-only for IdP)
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.name_prefix}-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.users_table}",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.providers_table}"
        ]
      }
    ]
  })
}

# Secrets Manager access (if enabled)
resource "aws_iam_role_policy" "secrets_manager" {
  count = var.secrets_manager_permissions ? 1 : 0
  name  = "${var.name_prefix}-secrets-policy"
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
  count      = var.provision_api ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
  role       = aws_iam_role.lambda_role.name
}

# X-Ray tracing permissions (if enabled)
resource "aws_iam_role_policy" "xray_tracing" {
  count = var.enable_tracing ? 1 : 0
  name  = "${var.name_prefix}-xray-policy"
  role  = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# Transfer Family invocation role (for direct Lambda)
resource "aws_iam_role" "transfer_invocation_role" {
  count = var.provision_api ? 0 : 1
  name = "${var.name_prefix}-transfer-invocation-role"

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
  count = var.provision_api ? 0 : 1
  name = "${var.name_prefix}-transfer-invoke-policy"
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
  count = var.provision_api ? 1 : 0
  name  = "${var.name_prefix}-transfer-api-gateway-role"

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
  count = var.provision_api ? 1 : 0
  name  = "${var.name_prefix}-transfer-api-gateway-policy"
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
