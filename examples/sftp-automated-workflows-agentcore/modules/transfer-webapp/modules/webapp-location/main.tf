# S3 Bucket (optional - only if create_bucket is true)
resource "aws_s3_bucket" "location" {
  count = var.create_bucket ? 1 : 0

  bucket_prefix = var.bucket_name != null ? "${var.bucket_name}-" : "transfer-${var.location_name}-"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name = var.location_name
    }
  )
}

resource "aws_s3_bucket_versioning" "location" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.location[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "location" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.location[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "location" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.location[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "location" {
  count = var.create_bucket && length(var.cors_allowed_origins) > 0 ? 1 : 0

  bucket = aws_s3_bucket.location[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers = [
      "last-modified",
      "content-length",
      "etag",
      "x-amz-version-id",
      "content-type",
      "x-amz-request-id",
      "x-amz-id-2",
      "date",
      "x-amz-cf-id",
      "x-amz-storage-class",
      "access-control-expose-headers"
    ]
    max_age_seconds = 3000
  }
}

# Data source for existing bucket (if not creating)
data "aws_s3_bucket" "existing" {
  count = var.create_bucket ? 0 : 1

  bucket = var.bucket_name
}

# Local values
locals {
  bucket_name = var.create_bucket ? aws_s3_bucket.location[0].id : data.aws_s3_bucket.existing[0].id
  bucket_arn  = var.create_bucket ? aws_s3_bucket.location[0].arn : data.aws_s3_bucket.existing[0].arn

  # Construct the S3 URI for the location
  s3_prefix_arn = var.bucket_prefix != "" ? "${local.bucket_arn}/${var.bucket_prefix}*" : "${local.bucket_arn}/*"
}

# IAM Role for Access Grants Location
resource "aws_iam_role" "location" {
  name_prefix = "${var.location_name}-access-grants-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AccessGrantsTrustPolicy"
        Effect = "Allow"
        Principal = {
          Service = "access-grants.s3.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:SetSourceIdentity"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "aws:SourceArn"     = var.access_grants_instance_arn
          }
        }
      },
      {
        Sid    = "AccessGrantsTrustPolicyWithIDCContext"
        Effect = "Allow"
        Principal = {
          Service = "access-grants.s3.amazonaws.com"
        }
        Action = "sts:SetContext"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "aws:SourceArn"     = var.access_grants_instance_arn
          }
          "ForAllValues:ArnEquals" = {
            "sts:RequestContextProviders" = "arn:aws:iam::aws:contextProvider/IdentityCenter"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "location" {
  name_prefix = "access-grants-location-policy-"
  role        = aws_iam_role.location.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ObjectLevelReadPermissions"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectAcl",
          "s3:GetObjectVersionAcl",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          local.s3_prefix_arn
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnEquals = {
            "s3:AccessGrantsInstanceArn" = [var.access_grants_instance_arn]
          }
        }
      },
      {
        Sid    = "ObjectLevelWritePermissions"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:PutObjectVersionAcl",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          local.s3_prefix_arn
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnEquals = {
            "s3:AccessGrantsInstanceArn" = [var.access_grants_instance_arn]
          }
        }
      },
      {
        Sid    = "BucketLevelReadPermissions"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          local.bucket_arn
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnEquals = {
            "s3:AccessGrantsInstanceArn" = [var.access_grants_instance_arn]
          }
        }
      }
    ]
  })
}

# Data source for current account
data "aws_caller_identity" "current" {}

# S3 Access Grants Location
resource "aws_s3control_access_grants_location" "location" {
  account_id     = data.aws_caller_identity.current.account_id
  iam_role_arn   = aws_iam_role.location.arn
  location_scope = var.bucket_prefix != "" ? "s3://${local.bucket_name}/${var.bucket_prefix}" : "s3://${local.bucket_name}"

  tags = var.tags
}
