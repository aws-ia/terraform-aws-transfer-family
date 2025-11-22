# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = var.password_policy.minimum_length
    require_lowercase                = var.password_policy.require_lowercase
    require_numbers                  = var.password_policy.require_numbers
    require_symbols                  = var.password_policy.require_symbols
    require_uppercase                = var.password_policy.require_uppercase
    temporary_password_validity_days = var.password_policy.temporary_password_validity_days
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

# Random suffix for domain uniqueness
resource "random_id" "domain_suffix" {
  byte_length = 3
}

# Cognito User Pool Domain for Managed Login
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.domain_prefix}-${random_id.domain_suffix.hex}"
  user_pool_id = aws_cognito_user_pool.main.id

  # Enable Managed Login (requires AWS provider >= 5.0)
  managed_login_version = 2
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = var.app_client_name
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = var.create_landing_page ? ["https://${aws_cloudfront_distribution.landing_page[0].domain_name}/callback"] : []
  logout_urls                          = var.create_landing_page ? ["https://${aws_cloudfront_distribution.landing_page[0].domain_name}"] : []

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Enable Cognito Managed Login
  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"
}

# Cognito Managed Login Branding (optional)
resource "aws_cognito_managed_login_branding" "main" {
  count = var.branding_settings != null ? 1 : 0

  user_pool_id = aws_cognito_user_pool.main.id
  client_id    = aws_cognito_user_pool_client.main.id

  settings = file(var.branding_settings)
}

# Data source for current region
data "aws_region" "current" {}

# S3 Bucket for landing page (optional)
resource "random_id" "bucket_suffix" {
  count       = var.create_landing_page ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  bucket        = var.landing_page_bucket_name != "" ? var.landing_page_bucket_name : "${var.domain_prefix}-landing-page-${random_id.bucket_suffix[0].hex}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name = "Cognito Landing Page"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  bucket = aws_s3_bucket.landing_page[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  bucket = aws_s3_bucket.landing_page[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Upload landing page HTML (optional)
resource "aws_s3_object" "landing_page" {
  count = var.create_landing_page && var.landing_page_template != null ? 1 : 0

  bucket = aws_s3_bucket.landing_page[0].id
  key    = "index.html"
  content = templatefile(var.landing_page_template, {
    user_pool_id   = aws_cognito_user_pool.main.id
    client_id      = aws_cognito_user_pool_client.main.id
    region         = data.aws_region.current.id
    cognito_domain = aws_cognito_user_pool_domain.main.domain
  })
  content_type = "text/html"
  etag = md5(templatefile(var.landing_page_template, {
    user_pool_id   = aws_cognito_user_pool.main.id
    client_id      = aws_cognito_user_pool_client.main.id
    region         = data.aws_region.current.id
    cognito_domain = aws_cognito_user_pool_domain.main.domain
  }))
}

# CloudFront Origin Access Control (optional)
resource "aws_cloudfront_origin_access_control" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  name                              = "${var.domain_prefix}-landing-page-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution (optional)
resource "aws_cloudfront_distribution" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.user_pool_name} Landing Page"

  origin {
    domain_name              = aws_s3_bucket.landing_page[0].bucket_regional_domain_name
    origin_id                = "S3-landing-page"
    origin_access_control_id = aws_cloudfront_origin_access_control.landing_page[0].id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-landing-page"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Custom error response to handle /callback path
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.user_pool_name} Landing Page"
    }
  )
}

# S3 Bucket Policy for CloudFront (optional)
resource "aws_s3_bucket_policy" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  bucket = aws_s3_bucket.landing_page[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.landing_page[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.landing_page[0].arn
          }
        }
      }
    ]
  })
}
