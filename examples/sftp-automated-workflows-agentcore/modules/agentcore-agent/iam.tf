resource "aws_iam_role" "execution" {
  name = "${local.resource_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock-agentcore.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "${local.resource_name}-bedrock-invoke"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = [
        "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}",
        "arn:aws:bedrock:*::foundation-model/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${local.resource_name}-logs"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/*"
    }]
  })
}

resource "aws_iam_role_policy" "s3_read" {
  name = "${local.resource_name}-s3-read"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetBucketLocation"
      ]
      Resource = [
        var.code_bucket_arn,
        "${var.code_bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "data_bucket_read" {
  count = length(var.data_bucket_arns) > 0 ? 1 : 0
  name  = "${local.resource_name}-data-bucket-read"
  role  = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.data_bucket_arns
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          for arn in var.data_bucket_arns : "${arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "xray_traces" {
  name = "${local.resource_name}-xray"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "invoke_gateway" {
  count = var.enable_gateway ? 1 : 0
  name  = "${local.resource_name}-invoke-gateway"
  role  = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock-agentcore:InvokeGateway"]
      Resource = var.gateway_arn
    }]
  })
}
