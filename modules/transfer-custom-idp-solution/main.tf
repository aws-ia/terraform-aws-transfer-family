#########################################
# S3 bucket to store CodeBuild artifacts 
#########################################


resource "aws_s3_bucket" "artifacts" {
  #checkov:skip=CKV2_AWS_62:Event notifications not required for build artifacts bucket
  #checkov:skip=CKV2_AWS_61:Lifecycle configuration not required for build artifacts bucket
  #checkov:skip=CKV_AWS_18:Access logging not required for build artifacts bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication not required for build artifacts bucket
  #checkov:skip=CKV_AWS_145:Using AWS managed encryption is acceptable for this use case
  bucket        = local.artifacts_bucket
  force_destroy = var.artifacts_force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#########################################
# DynamoDB Tables
#########################################


resource "aws_dynamodb_table" "users" {
  #checkov:skip=CKV_AWS_119:Using AWS managed encryption is acceptable for this use case
  count = var.users_table_name == "" ? 1 : 0

  name              = local.users_table
  billing_mode      = "PAY_PER_REQUEST"
  hash_key          = "user"
  range_key         = "identity_provider_key"
  deletion_protection_enabled = var.enable_deletion_protection

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

  tags = local.common_tags
}


resource "aws_dynamodb_table" "identity_providers" {
  #checkov:skip=CKV_AWS_119:Using AWS managed encryption is acceptable for this use case
  count = var.identity_providers_table_name == "" ? 1 : 0

  name         = local.providers_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "provider"
  deletion_protection_enabled = var.enable_deletion_protection

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

  tags = local.common_tags
}

######################################################################################
# CodeBuild project to download code from Tookit Git repo and publish artifacts to S3
######################################################################################


resource "aws_codebuild_project" "build" {
  #checkov:skip=CKV_AWS_147:Using AWS managed encryption is acceptable for this use case
  name          = local.codebuild_project
  description   = "Build Lambda artifacts for Transfer Family Custom IdP"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30
  
  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifacts.bucket
    path = ""
    packaging = "ZIP"
  }
  
  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    
    environment_variable {
      name  = "ARTIFACTS_BUCKET"
      value = aws_s3_bucket.artifacts.bucket
    }
    
    environment_variable {
      name  = "FUNCTION_ARTIFACT_KEY"
      value = local.function_artifact_key
    }
    
    environment_variable {
      name  = "LAYER_ARTIFACT_KEY"
      value = local.layer_artifact_key
    }
    
    environment_variable {
      name  = "GITHUB_REPO"
      value = var.github_repository_url
    }
    
    environment_variable {
      name  = "GITHUB_BRANCH"
      value = var.github_branch
    }
    
    environment_variable {
      name  = "SOLUTION_PATH"
      value = var.solution_path
    }
  }
  
  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspec.yml")
  }
  
  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.codebuild_project}"
    }
  }
  
  tags = local.common_tags
}

########################################
# Trigger CodeBuild to create artifacts
########################################

resource "null_resource" "build_trigger" {
  triggers = {
    force_build        = var.force_build ? timestamp() : "false"
    codebuild_project  = aws_codebuild_project.build.id
    github_repo        = var.github_repository_url
    github_branch      = var.github_branch
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for IAM role propagation..."
      sleep 10
      
      BUILD_ID=$(aws codebuild start-build \
        --project-name ${aws_codebuild_project.build.name} \
        --query 'build.id' \
        --output text)
      
      echo "CodeBuild started: $BUILD_ID"
      
      # Wait for build to complete
      while true; do
        BUILD_STATUS=$(aws codebuild batch-get-builds \
          --ids $BUILD_ID \
          --query 'builds[0].buildStatus' \
          --output text)
        
        if [ "$BUILD_STATUS" == "SUCCEEDED" ]; then
          echo "Build succeeded"
          exit 0
        elif [ "$BUILD_STATUS" == "FAILED" ] || [ "$BUILD_STATUS" == "FAULT" ] || [ "$BUILD_STATUS" == "TIMED_OUT" ] || [ "$BUILD_STATUS" == "STOPPED" ]; then
          echo "Build failed with status: $BUILD_STATUS"
          exit 1
        fi
        
        echo "Build status: $BUILD_STATUS, waiting..."
        sleep 10
      done
    EOT
  }
  
  depends_on = [
    aws_codebuild_project.build,
    aws_s3_bucket.artifacts,
    aws_iam_role_policy.codebuild_policy
  ]
}

######################################
# IAM Role for CodeBuild
######################################

resource "aws_iam_role" "codebuild_role" {
  name = "${var.name_prefix}-custom-idp-codebuild-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  
  tags = local.common_tags
}

######################################
# IAM policy for CodeBuild role
######################################

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.name_prefix}-custom-idp-codebuild-policy"
  role        = aws_iam_role.codebuild_role.id
  
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
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.codebuild_project}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

#########################################
# Lambda resources
#########################################

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

# Lambda layer for dependencies
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

# Lambda function for identity provider

resource "aws_lambda_function" "identity_provider" {
  #checkov:skip=CKV_AWS_116:DLQ not required for synchronous IdP authentication flow
  #checkov:skip=CKV_AWS_173:Using AWS managed encryption is acceptable for this use case
  #checkov:skip=CKV_AWS_272:Code signing adds operational complexity without significant security benefit
  #checkov:skip=CKV_AWS_115:Concurrent execution limit not required, AWS manages throttling
  function_name = local.function_name
  description   = "AWS Transfer Family Custom IdP Handler"
  role          = aws_iam_role.lambda_role.arn
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
    aws_lambda_layer_version.dependencies
  ]

  tags = local.common_tags
}

# Lambda permission for AWS Transfer Family to invoke the function
resource "aws_lambda_permission" "transfer_invoke" {
  count          = var.provision_api ? 0 : 1
  statement_id   = "AllowTransferFamilyInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.identity_provider.function_name
  principal      = "transfer.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway_invoke" {
  count         = var.provision_api ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.identity_provider.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.identity_provider[0].execution_arn}/*/*"
}

#########################################
# API Gateway resources
#########################################

# API Gateway for identity provider
resource "aws_api_gateway_rest_api" "identity_provider" {
  #checkov:skip=CKV_AWS_237: Not applicable in this use case
  #checkov:skip=CKV_AWS_217: Not applicable in this use case
  count = var.provision_api ? 1 : 0
  name  = "${var.name_prefix}-identity-provider-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "servers" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_rest_api.identity_provider[0].root_resource_id
  path_part   = "servers"
}

resource "aws_api_gateway_resource" "server_id" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.servers[0].id
  path_part   = "{serverId}"
}

resource "aws_api_gateway_resource" "users" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.server_id[0].id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "username" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.users[0].id
  path_part   = "{username}"
}

resource "aws_api_gateway_resource" "config" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.username[0].id
  path_part   = "config"
}


resource "aws_api_gateway_method" "get_user_config" {
  #checkov:skip=CKV2_AWS_53:Request validation not required for Transfer Family IdP integration
  count         = var.provision_api ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.identity_provider[0].id
  resource_id   = aws_api_gateway_resource.config[0].id
  http_method   = "GET"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "lambda" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  resource_id = aws_api_gateway_resource.config[0].id
  http_method = aws_api_gateway_method.get_user_config[0].http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.identity_provider.invoke_arn

  request_templates = {
    "application/json" = <<EOF
{
  "username": "$input.params('username')",
  "serverId": "$input.params('serverId')",
  "password": "$util.escapeJavaScript($input.params('Password')).replaceAll("\\\\'","'")",
  "sourceIp": "$util.escapeJavaScript($input.params('SourceIp')).replaceAll("\\\\'","'")",
  "protocol": "$input.params('protocol')"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "success" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  resource_id = aws_api_gateway_resource.config[0].id
  http_method = aws_api_gateway_method.get_user_config[0].http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "success" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  resource_id = aws_api_gateway_resource.config[0].id
  http_method = aws_api_gateway_method.get_user_config[0].http_method
  status_code = aws_api_gateway_method_response.success[0].status_code

  depends_on = [aws_api_gateway_integration.lambda[0]]
}

resource "aws_api_gateway_deployment" "identity_provider" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id

  depends_on = [
    aws_api_gateway_method.get_user_config[0],
    aws_api_gateway_integration.lambda[0],
    aws_api_gateway_method_response.success[0],
    aws_api_gateway_integration_response.success[0]
  ]
}

resource "aws_api_gateway_stage" "identity_provider" {
  #checkov:skip=CKV2_AWS_4:CloudWatch logging is optional for this use case
  #checkov:skip=CKV2_AWS_51:Client certificate authentication not required for AWS IAM authenticated API
  #checkov:skip=CKV2_AWS_76:API actions loggging is already present in a cloudwatch log group
  #checkov:skip=CKV2_AWS_29:WAF not required for internal Transfer Family IdP API
  #checkov:skip=CKV_AWS_73:X-ray tracing is available to be enabled via the variables file
  #checkov:skip=CKV_AWS_120:API Gateway caching is optional in this use case
  count         = var.provision_api ? 1 : 0
  deployment_id = aws_api_gateway_deployment.identity_provider[0].id
  rest_api_id   = aws_api_gateway_rest_api.identity_provider[0].id
  stage_name    = "prod"

  xray_tracing_enabled = var.enable_tracing

  tags = local.common_tags
}
