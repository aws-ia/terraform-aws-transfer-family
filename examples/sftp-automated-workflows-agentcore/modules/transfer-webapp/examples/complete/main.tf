# Complete example demonstrating Transfer Family Web App with S3 Access Grants and multiple locations

# S3 Access Grants Instance
# Note: Only one instance can exist per AWS account
resource "aws_s3control_access_grants_instance" "main" {
  identity_center_arn = var.identity_center_instance_arn
}

# Create an existing S3 bucket to demonstrate using pre-existing buckets
# This bucket is created outside the transfer_webapp_location module
resource "aws_s3_bucket" "shared" {
  bucket        = var.shared_bucket_name
  force_destroy = true

  tags = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Example     = "complete"
    Purpose     = "shared-documents"
  }
}

resource "aws_s3_bucket_versioning" "shared" {
  bucket = aws_s3_bucket.shared.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "shared" {
  bucket = aws_s3_bucket.shared.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create the Transfer Family Web App
module "transfer_webapp" {
  source = "../../"

  web_app_name                 = var.web_app_name
  identity_center_instance_arn = var.identity_center_instance_arn
  access_grants_instance_arn   = aws_s3control_access_grants_instance.main.access_grants_instance_arn

  tags = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Example     = "complete"
  }
}

# Location 1: User uploads bucket
# Creates a new S3 bucket for user uploads with CORS configured
module "uploads_location" {
  source = "../../modules/webapp-location"

  location_name              = "uploads"
  create_bucket              = true
  bucket_name                = var.uploads_bucket_name
  bucket_prefix              = ""
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn
  cors_allowed_origins       = [module.transfer_webapp.web_app_endpoint]

  tags = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Example     = "complete"
    Purpose     = "user-uploads"
  }
}

# Location 2: Shared documents bucket (using existing bucket)
# Uses the existing S3 bucket created above with a specific prefix
# This demonstrates how to use pre-existing buckets with the location module
module "shared_location" {
  source = "../../modules/webapp-location"

  location_name              = "shared-docs"
  create_bucket              = false
  bucket_name                = aws_s3_bucket.shared.id
  bucket_prefix              = "documents/"
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn

  tags = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Example     = "complete"
    Purpose     = "shared-documents"
  }

  depends_on = [aws_s3_bucket.shared]
}

# Assign users and groups to the web app with access grants
module "webapp_users_and_groups" {
  source = "../../modules/webapp-users-groups"

  web_app_arn                = module.transfer_webapp.web_app_arn
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn

  # User 1: With access grants to multiple locations
  # This user gets READWRITE access to their personal folder in uploads
  # and READ access to shared documents
  users = [
    {
      username = var.user1_username
      access_grants = [
        {
          location_id = module.uploads_location.location_id
          path        = "user/${var.user1_username}/*"
          permission  = "READWRITE"
        },
        {
          location_id = module.shared_location.location_id
          path        = "*"
          permission  = "READ"
        }
      ]
    },
    # User 2: Without access grants
    # This demonstrates assigning a user to the web app without managing
    # their access grants through this module. This is useful when access
    # grants are managed elsewhere or through a different process.
    {
      username      = var.user2_username
      access_grants = null
    }
  ]

  # Group: With read-only access to shared documents
  # All members of this group will have READ access to shared documents
  groups = [
    {
      group_name = var.group_name
      access_grants = [
        {
          location_id = module.shared_location.location_id
          path        = "*"
          permission  = "READ"
        }
      ]
    }
  ]

  tags = {
    Environment = "demo"
    ManagedBy   = "terraform"
    Example     = "complete"
  }
}
