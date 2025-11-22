resource "aws_codebuild_project" "build" {
  name          = local.codebuild_project
  description   = "Build Lambda artifacts for Transfer Family Custom IdP"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.artifacts.bucket
    path      = ""
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
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${local.codebuild_project}"
  retention_in_days = 7
  tags              = local.common_tags
}

# Trigger CodeBuild to create artifacts
resource "null_resource" "build_trigger" {
  triggers = {
    force_build       = var.force_build ? timestamp() : "false"
    codebuild_project = aws_codebuild_project.build.id
    github_repo       = var.github_repository_url
    github_branch     = var.github_branch
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
    aws_iam_role_policy.codebuild,
    aws_cloudwatch_log_group.codebuild
  ]
}
