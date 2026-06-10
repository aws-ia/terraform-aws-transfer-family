################################################################################
# Web Application for Internal Users
# Components: Transfer Family Web App with S3 Access Grants
################################################################################

################################################################################
# Step 1: Deploy Transfer Family Web App
################################################################################

# Use the module to deploy web application for internal claims team access
module "transfer_webapp" {
  count  = var.enable_webapp ? 1 : 0
  source = "../../modules/transfer-web-app"

  iam_role_name = "anycompany-insurance-webapp-role"

  # Web apps are configured with an IAM Identity Center instance
  identity_center_instance_arn = local.sso_instance_arn
  identity_store_id            = local.identity_store_id

  # S3 Access Grants — instance is created by the transfer-web-app module
  # itself when no s3_access_grants_instance_id is provided.

  # Group-based access grants are managed in the identity_center_groups attribute.
  # IAM Identity Center groups are automatically assigned to the web app and
  # S3 Access Grants are created for each group's defined paths.
  identity_center_groups = [
    {
      # Claims Admins: Full read/write access to all files in the clean-files bucket
      group_name = "Claims Admins"
      access_grants = [
        {
          s3_path    = "${module.s3_bucket_clean[0].s3_bucket_id}/*"
          permission = "READWRITE"
        }
      ]
    },
    {
      # Claims Reviewers: Read-only access to submitted and processed claims
      group_name = "Claims Reviewers"
      access_grants = [
        {
          s3_path    = "${module.s3_bucket_clean[0].s3_bucket_id}/*"
          permission = "READ"
        }
      ]
    }
  ]

  tags = var.tags

  depends_on = [
    aws_identitystore_user.claims_reviewer,
    aws_identitystore_user.claims_administrator,
    aws_identitystore_group.claims_admins,
    aws_identitystore_group.claims_reviewers,
    module.s3_bucket_clean
  ]
}

################################################################################
# Step 2: CORS Configuration for Clean Bucket
################################################################################

# CORS must be configured on the bucket to use the bucket with Transfer Web Apps
resource "aws_s3_bucket_cors_configuration" "clean_bucket_cors" {
  count  = var.enable_webapp ? 1 : 0
  bucket = module.s3_bucket_clean[0].s3_bucket_id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [module.transfer_webapp[0].web_app_endpoint]
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
