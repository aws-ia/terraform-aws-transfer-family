# Transfer Web App Module
# This module creates web application resources for AWS Transfer Family

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_ssoadmin_instances" "this" {}

# IAM assume role policy for Transfer service
data "aws_iam_policy_document" "assume_role_transfer" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:SetContext"
    ]
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
  }
}

# IAM role for Transfer web app
resource "aws_iam_role" "transfer_web_app" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_transfer.json
  tags               = var.tags
}

# IAM policy document for S3 Access Grants
data "aws_iam_policy_document" "transfer_web_app" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetDataAccess",
      "s3:ListCallerAccessGrants",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:access-grants/*"
    ]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "s3:ResourceAccount"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListAccessGrantsInstances"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "s3:ResourceAccount"
    }
  }
}

# IAM role policy attachment
resource "aws_iam_role_policy" "transfer_web_app" {
  policy = data.aws_iam_policy_document.transfer_web_app.json
  role   = aws_iam_role.transfer_web_app.name
}

# Transfer Web App
resource "aws_transfer_web_app" "this" {
  identity_provider_details {
    identity_center_config {
      instance_arn = var.identity_center_instance_arn != null ? var.identity_center_instance_arn : tolist(data.aws_ssoadmin_instances.this.arns)[0]
      role         = aws_iam_role.transfer_web_app.arn
    }
  }
  
  web_app_units {
    provisioned = var.provisioned_units
  }
  
  tags = var.tags
}
