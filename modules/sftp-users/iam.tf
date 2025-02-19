# Create IAM role for SFTP users
resource "aws_iam_role" "sftp_user_roles" {
  for_each = { for user in var.users : user.username => user }

  name = "transfer-user-${each.value.username}"

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
}

# Update the IAM role policy for SFTP users
resource "aws_iam_role_policy" "sftp_user_policies" {
  for_each = { for user in var.users : user.username => user }

  name = "sftp-user-policy-${each.value.username}"
  role = aws_iam_role.sftp_user_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.s3_bucket_arn
        ]
        # Condition = {
        #   StringLike = {
        #     "s3:prefix" = ["${each.value.home_dir}/*", "${each.value.home_dir}", ""]
        #   }
        # }
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = [
          "${var.s3_bucket_arn}${each.value.home_dir}/*",
          "${var.s3_bucket_arn}${each.value.home_dir}"
        ]
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.sse_encryption.arn
        ]
      }
    ]
  })
}