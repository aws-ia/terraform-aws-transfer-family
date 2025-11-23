################################################################################
# Stage 4: Web Application for Internal Users
# Components: Transfer Family Web App with S3 Access Grants
################################################################################

################################################################################
# Step 1: Deploy Transfer Family Web App
################################################################################

# Use the module to deploy web application for internal claims team access
module "transfer_webapp" {
  count  = var.enable_webapp ? 1 : 0
  source = "./modules/transfer-webapp"

  web_app_name                 = "anycompany-insurance-webapp"

  # Web apps are configured with an IAM Identity Center instance
  identity_center_instance_arn = local.sso_instance_arn

  # S3 Access Grants to control file access
  access_grants_instance_arn   = aws_s3control_access_grants_instance.main[0].access_grants_instance_arn

  tags = var.tags
}

################################################################################
# Step 2: Create S3 Access Grants Location
################################################################################

# Use the webapp-location submodule to configure S3 Access Grants location for clean files bucket
module "clean_location" {
  count  = var.enable_webapp ? 1 : 0
  source = "./modules/transfer-webapp/modules/webapp-location"

  location_name              = "clean-files"
  
  # The submodule can automatically create a bucket for the location or use an existing one
  create_bucket              = false
  bucket_name                = module.s3_bucket_clean[0].s3_bucket_id
  access_grants_instance_arn = module.transfer_webapp[0].access_grants_instance_arn

  # CORS must be configured on the bucket to use the bucket with Transfer Web Apps
  cors_allowed_origins       = [module.transfer_webapp[0].web_app_endpoint]

  tags = var.tags

  depends_on = [module.s3_bucket_clean]
}

################################################################################
# Step 3: Assign User and Group Access to Web Apps and Create Access Grants
################################################################################

# The webapps-users-groups submodule assigns users and groups to the Web app
# and can automatically create S3 Access Grants
module "webapp_users_and_groups" {
  count  = var.enable_webapp ? 1 : 0
  source = "./modules/transfer-webapp/modules/webapp-users-groups"

  # The submodule requires a Web app and S3 Access Grants instance
  web_app_arn                = module.transfer_webapp[0].web_app_arn
  access_grants_instance_arn = module.transfer_webapp[0].access_grants_instance_arn

  depends_on = [
    aws_identitystore_user.claims_reviewer,
    aws_identitystore_user.claims_administrator,
    aws_identitystore_group.claims_admins,
    aws_identitystore_group.claims_reviewers
  ]

  # Group-based access grants is managed in the groups attribute. IAM Identity Center 
  # group are automatically assigned to the web app
  groups = [
    {
      # Claims Admins: Full read/write access to all files in the clean-files bucket
      group_name = aws_identitystore_group.claims_admins[0].display_name
      
      access_grants = [
        {
          location_id = module.clean_location[0].location_id
          path        = "*"
          permission  = "READWRITE"
        }
      ]
    },
    {
      # Claims Reviewers: Read-only access to submitted and processed claims
      group_name = aws_identitystore_group.claims_reviewers[0].display_name
      access_grants = [
        {
          location_id = module.clean_location[0].location_id
          path        = "submitted-claims/*"
          permission  = "READ"
        },
        {
          location_id = module.clean_location[0].location_id
          path        = "processed-claims/*"
          permission  = "READ"
        }
      ]
    }
  ]

  tags = var.tags
}

################################################################################
# Step 3: CORS Configuration for Clean Bucket
################################################################################

# Add CORS configuration to the existing clean bucket for webapp access
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
