# Data sources to detect artifact changes
data "aws_s3_object" "layer_artifact" {
  bucket = aws_s3_bucket.artifacts.bucket
  key    = local.layer_artifact_key

  depends_on = [null_resource.build_trigger]
}

data "aws_s3_object" "function_artifact" {
  bucket = aws_s3_bucket.artifacts.bucket
  key    = local.function_artifact_key

  depends_on = [null_resource.build_trigger]
}

# Lambda Layer
resource "aws_lambda_layer_version" "dependencies" {
  layer_name          = local.layer_name
  s3_bucket           = aws_s3_bucket.artifacts.bucket
  s3_key              = local.layer_artifact_key
  s3_object_version   = data.aws_s3_object.layer_artifact.version_id
  compatible_runtimes = [var.lambda_runtime]
  description         = "Dependencies for Transfer Family Custom IdP"
  source_code_hash    = data.aws_s3_object.layer_artifact.etag

  depends_on = [null_resource.build_trigger]
}

# Lambda Function
resource "aws_lambda_function" "handler" {
  function_name = local.function_name
  description   = "AWS Transfer Family Custom IdP Handler"
  role          = aws_iam_role.lambda.arn
  handler       = "app.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket         = aws_s3_bucket.artifacts.bucket
  s3_key            = local.function_artifact_key
  s3_object_version = data.aws_s3_object.function_artifact.version_id
  source_code_hash  = data.aws_s3_object.function_artifact.etag

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      USERS_TABLE              = local.users_table
      IDENTITY_PROVIDERS_TABLE = local.providers_table
      USER_NAME_DELIMITER      = var.username_delimiter
      LOGLEVEL                 = var.log_level
      AWS_XRAY_TRACING_NAME    = local.function_name
    }
  }

  dynamic "vpc_config" {
    for_each = local.vpc_config != null ? [local.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tracing_config {
    mode = var.enable_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    null_resource.build_trigger,
    aws_lambda_layer_version.dependencies,
    aws_cloudwatch_log_group.lambda
  ]

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Allow Transfer Family to invoke Lambda
resource "aws_lambda_permission" "transfer_family" {
  statement_id   = "AllowTransferFamilyInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.handler.function_name
  principal      = "transfer.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}
