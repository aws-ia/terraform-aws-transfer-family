locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# DynamoDB Table for Claims
resource "aws_dynamodb_table" "claims" {
  name         = "claims-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "claim_id"

  attribute {
    name = "claim_id"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECR Repositories
resource "aws_ecr_repository" "workflow_agent" {
  name                 = "${local.name_prefix}-workflow-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "${local.name_prefix}-workflow-agent"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_repository" "entity_extraction_agent" {
  name                 = "${local.name_prefix}-entity-extraction-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "${local.name_prefix}-entity-extraction-agent"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_repository" "fraud_validation_agent" {
  name                 = "${local.name_prefix}-fraud-validation-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "${local.name_prefix}-fraud-validation-agent"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_repository" "database_insertion_agent" {
  name                 = "${local.name_prefix}-database-insertion-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "${local.name_prefix}-database-insertion-agent"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_ecr_repository" "summary_generation_agent" {
  name                 = "${local.name_prefix}-summary-generation-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name        = "${local.name_prefix}-summary-generation-agent"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Get ECR authorization token
data "aws_ecr_authorization_token" "token" {}

# Build and push Docker images
resource "null_resource" "workflow_agent_image" {
  depends_on = [aws_ecr_repository.workflow_agent]

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/docker/Dockerfile.workflow")
    agent_hash        = filesha256("${path.module}/agents/orchestrator/claims_workflow.py")
    requirements_hash = filesha256("${path.module}/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      if ! command -v docker &> /dev/null; then
        echo "Docker is not installed or not in PATH. Please install Docker and try again."
        exit 1
      fi
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_ecr_authorization_token.token.proxy_endpoint}
      
      docker build -t ${aws_ecr_repository.workflow_agent.repository_url}:latest -f ${path.module}/docker/Dockerfile.workflow ${path.module}
      docker push ${aws_ecr_repository.workflow_agent.repository_url}:latest
    EOF
  }
}

resource "null_resource" "entity_extraction_agent_image" {
  depends_on = [aws_ecr_repository.entity_extraction_agent]

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/docker/Dockerfile.entity")
    agent_hash        = filesha256("${path.module}/agents/individual_agents/entity_extraction_agent.py")
    requirements_hash = filesha256("${path.module}/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_ecr_authorization_token.token.proxy_endpoint}
      
      docker build -t ${aws_ecr_repository.entity_extraction_agent.repository_url}:latest -f ${path.module}/docker/Dockerfile.entity ${path.module}
      docker push ${aws_ecr_repository.entity_extraction_agent.repository_url}:latest
    EOF
  }
}

resource "null_resource" "fraud_validation_agent_image" {
  depends_on = [aws_ecr_repository.fraud_validation_agent]

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/docker/Dockerfile.fraud")
    agent_hash        = filesha256("${path.module}/agents/individual_agents/fraud_validation_agent.py")
    requirements_hash = filesha256("${path.module}/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_ecr_authorization_token.token.proxy_endpoint}
      
      docker build -t ${aws_ecr_repository.fraud_validation_agent.repository_url}:latest -f ${path.module}/docker/Dockerfile.fraud ${path.module}
      docker push ${aws_ecr_repository.fraud_validation_agent.repository_url}:latest
    EOF
  }
}

resource "null_resource" "database_insertion_agent_image" {
  depends_on = [aws_ecr_repository.database_insertion_agent]

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/docker/Dockerfile.db")
    agent_hash        = filesha256("${path.module}/agents/individual_agents/database_insertion_agent.py")
    requirements_hash = filesha256("${path.module}/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_ecr_authorization_token.token.proxy_endpoint}
      
      docker build -t ${aws_ecr_repository.database_insertion_agent.repository_url}:latest -f ${path.module}/docker/Dockerfile.db ${path.module}
      docker push ${aws_ecr_repository.database_insertion_agent.repository_url}:latest
    EOF
  }
}

resource "null_resource" "summary_generation_agent_image" {
  depends_on = [aws_ecr_repository.summary_generation_agent]

  triggers = {
    dockerfile_hash   = filesha256("${path.module}/docker/Dockerfile.summary")
    agent_hash        = filesha256("${path.module}/agents/individual_agents/summary_report_agent.py")
    requirements_hash = filesha256("${path.module}/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
      source ~/.bash_profile || source ~/.profile || true
      
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_ecr_authorization_token.token.proxy_endpoint}
      
      docker build -t ${aws_ecr_repository.summary_generation_agent.repository_url}:latest -f ${path.module}/docker/Dockerfile.summary ${path.module}
      docker push ${aws_ecr_repository.summary_generation_agent.repository_url}:latest
    EOF
  }
}

# EventBridge and Lambda Trigger Infrastructure
# IAM Role for Lambda
resource "aws_iam_role" "claims_processor_role" {
  name = "claims-processor-trigger-role"

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
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "claims_processor_policy" {
  name = "claims-processor-policy"
  role = aws_iam_role.claims_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeAgentRuntime"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectTagging",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:PutObjectTagging",
          "s3:CopyObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
}

# Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/lambda_function.zip"
  source {
    content = templatefile("${path.module}/lambda/lambda_trigger.py", {
      workflow_runtime_arn = module.workflow_agent.agent_runtime_arn
    })
    filename = "lambda_function.py"
  }
}

# Lambda function
resource "aws_lambda_function" "claims_processor" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "claims-processor-trigger"
  role          = aws_iam_role.claims_processor_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300
  memory_size   = 256

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  description = "Triggers claims processing workflow on S3 uploads"

  environment {
    variables = {
      WORKFLOW_RUNTIME_ARN = module.workflow_agent.agent_runtime_arn
    }
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "claims_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.claims_processor.function_name}"
  retention_in_days = 14
}

# Data sources for account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Additional IAM policy for workflow agent to invoke other agents
resource "aws_iam_policy" "workflow_agent_cross_invoke_policy" {
  name        = "workflow-agent-cross-invoke-policy-${random_id.suffix.hex}"
  description = "Allow workflow agent broader workload identity access and runtime invocation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BroadWorkloadIdentityAccess"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:GetWorkloadAccessToken",
          "bedrock-agentcore:GetWorkloadAccessTokenForJWT",
          "bedrock-agentcore:GetWorkloadAccessTokenForUserId"
        ]
        Resource = [
          "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
          "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/*"
        ]
      },
      {
        Sid    = "InvokeAnyAgentRuntime"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:InvokeAgentRuntime"
        ]
        Resource = [
          "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:runtime/*"
        ]
      }
    ]
  })
}

# Get workflow agent role name from ARN
locals {
  workflow_agent_role_name = split("/", module.workflow_agent.runtime_role_arn)[1]
}

# Attach the cross-invoke policy to workflow agent role
resource "aws_iam_role_policy_attachment" "workflow_agent_cross_invoke_attachment" {
  role       = local.workflow_agent_role_name
  policy_arn = aws_iam_policy.workflow_agent_cross_invoke_policy.arn
}

# Reference existing S3 bucket
data "aws_s3_bucket" "claims_bucket" {
  bucket = var.bucket_name
}

# S3 Bucket Notification Configuration
resource "aws_s3_bucket_notification" "claims_bucket_notification" {
  bucket      = data.aws_s3_bucket.claims_bucket.id
  eventbridge = true
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "s3_upload_rule" {
  name        = "claims-s3-upload-rule"
  description = "Trigger claims processing on PDF uploads (claim-* folders only)"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.bucket_name]
      }
      object = {
        key = [
          {
            prefix = "claim-"
          }
        ]
      }
    }
  })
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_upload_rule.name
  target_id = "TriggerLambdaFunction"
  arn       = aws_lambda_function.claims_processor.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.claims_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_upload_rule.arn
}
