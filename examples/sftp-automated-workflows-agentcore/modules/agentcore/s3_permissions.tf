# S3 permissions for all agents
resource "aws_iam_policy" "agents_s3_policy" {
  name        = "agents-s3-policy-${random_id.suffix.hex}"
  description = "S3 permissions for all agents to read from bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Sid    = "S3WriteAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
}

# DynamoDB permissions for agents
resource "aws_iam_policy" "agents_dynamodb_policy" {
  name        = "agents-dynamodb-policy-${random_id.suffix.hex}"
  description = "DynamoDB permissions for agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
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
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/claims-table"
        ]
      }
    ]
  })
}

# Get agent role names from ARNs
locals {
  entity_extraction_agent_role_name  = split("/", module.entity_extraction_agent.runtime_role_arn)[1]
  fraud_validation_agent_role_name   = split("/", module.fraud_validation_agent.runtime_role_arn)[1]
  database_insertion_agent_role_name = split("/", module.database_insertion_agent.runtime_role_arn)[1]
  summary_generation_agent_role_name = split("/", module.summary_generation_agent.runtime_role_arn)[1]
}

# Attach S3 policy to all agent roles
resource "aws_iam_role_policy_attachment" "entity_extraction_s3_attachment" {
  role       = local.entity_extraction_agent_role_name
  policy_arn = aws_iam_policy.agents_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "fraud_validation_s3_attachment" {
  role       = local.fraud_validation_agent_role_name
  policy_arn = aws_iam_policy.agents_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "database_insertion_s3_attachment" {
  role       = local.database_insertion_agent_role_name
  policy_arn = aws_iam_policy.agents_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "summary_generation_s3_attachment" {
  role       = local.summary_generation_agent_role_name
  policy_arn = aws_iam_policy.agents_s3_policy.arn
}

# Attach DynamoDB policy to relevant agent roles
resource "aws_iam_role_policy_attachment" "fraud_validation_dynamodb_attachment" {
  role       = local.fraud_validation_agent_role_name
  policy_arn = aws_iam_policy.agents_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "database_insertion_dynamodb_attachment" {
  role       = local.database_insertion_agent_role_name
  policy_arn = aws_iam_policy.agents_dynamodb_policy.arn
}
