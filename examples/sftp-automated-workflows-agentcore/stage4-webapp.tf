################################################################################
# Stage 4: Web Application for Internal Users
# Components: Transfer Family Web App with S3 Access Grants
################################################################################

module "transfer_webapp" {
  count  = var.enable_webapp ? 1 : 0
  source = "../../modules/transfer-web-app"

  iam_role_name                = "anycompany-insurance-webapp-role"
  identity_center_instance_arn = local.sso_instance_arn
  identity_store_id            = local.identity_store_id

  # S3 Access Grants — use the instance created in stage0
  s3_access_grants_instance_id = aws_s3control_access_grants_instance.main[0].access_grants_instance_id

  # Group-based access to the clean files bucket
  identity_center_groups = [
    {
      group_name = "Claims Admins"
      access_grants = [
        {
          s3_path    = "${module.s3_bucket_clean[0].s3_bucket_id}/*"
          permission = "READWRITE"
        }
      ]
    },
    {
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
# CORS Configuration for Clean Bucket
################################################################################

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
