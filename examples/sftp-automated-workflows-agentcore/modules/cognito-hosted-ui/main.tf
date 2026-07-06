# ─────────────────────────────────────────────────────────────────────────────
# Cognito Hosted UI module
#
# Creates a Cognito user pool with admin-only user creation, an app client with
# OAuth 2.0 authorization-code flow, a Cognito-managed domain with Managed
# Login v2 enabled, and (optionally) custom branding loaded from a JSON
# settings file.
#
# When `create_landing_page = true` (default), also provisions a private S3
# bucket hosting a templated `index.html`, a CloudFront distribution that
# fronts the bucket via an Origin Access Control, an S3 bucket policy granting
# CloudFront read access, and wires the CloudFront domain into the app
# client's callback_urls and logout_urls.
#
# Components created below:
#   • aws_cognito_user_pool                       — user directory
#   • aws_cognito_user_pool_domain                — Cognito-managed login URL
#   • aws_cognito_user_pool_client                — OAuth app client
#   • aws_cognito_managed_login_branding          — optional, JSON-driven theme
#   • aws_s3_bucket (+ PAB, versioning, policy)   — optional landing page host
#   • aws_s3_object.landing_page                  — optional templated HTML
#   • aws_cloudfront_origin_access_control        — optional, S3 origin auth
#   • aws_cloudfront_distribution                 — optional, public HTTPS edge
# ─────────────────────────────────────────────────────────────────────────────

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
    allow_admin_create_user_only = true
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
  #checkov:skip=CKV2_AWS_6: "Public access block is configured by aws_s3_bucket_public_access_block.landing_page below; checkov's static analysis does not always trace count-indexed associations across separate resources (see bridgecrewio/checkov#2327)."
  #checkov:skip=CKV_AWS_21: "Versioning is configured by aws_s3_bucket_versioning.landing_page below; checkov's static analysis does not always trace count-indexed associations across separate resources."
  #checkov:skip=CKV_AWS_18: "Access logging not required for landing-page bucket; CloudFront access logging is intentionally not enabled per the existing CKV_AWS_86 skip on the distribution."
  #checkov:skip=CKV_AWS_144: "Cross-region replication not required for landing-page bucket"
  #checkov:skip=CKV_AWS_145: "Using AWS managed encryption is acceptable for this use case"
  #checkov:skip=CKV2_AWS_61: "Lifecycle configuration not required for landing-page bucket"
  #checkov:skip=CKV2_AWS_62: "Event notifications not required for landing-page bucket"
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

# CloudFront Response Headers Policy — adds standard security headers
# (HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy) to every
# response served by the landing-page distribution.
resource "aws_cloudfront_response_headers_policy" "landing_page" {
  count = var.create_landing_page ? 1 : 0

  name = "${var.domain_prefix}-landing-page-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
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
  #checkov:skip=CKV_AWS_86: "Landing page is a public static redirect target for the Cognito hosted UI; it serves no user-specific or sensitive content. CloudFront access logging adds an S3 bucket with no auditable signal for this use case."
  #checkov:skip=CKV_AWS_68: "WAF protection is not required for a public, static Cognito hosted-UI landing page that serves only a single HTML redirect. Adding WAF would incur monthly cost with no real attack surface to defend."
  #checkov:skip=CKV_AWS_174: "Uses cloudfront_default_certificate which pins to TLSv1 for *.cloudfront.net domains. A custom TLS 1.2+ policy requires an ACM certificate bound to a custom domain, which is out of scope for this example."
  #checkov:skip=CKV_AWS_310: "Origin failover requires a second S3 origin; the landing page is single-origin static content where failover adds complexity with no reliability benefit for this example."
  #checkov:skip=CKV_AWS_374: "Geo restriction is intentionally disabled to allow global access to the public Cognito hosted UI landing page; adding restrictions would break legitimate users."
  #checkov:skip=CKV2_AWS_42: "Custom SSL certificate requires an ACM certificate bound to a custom domain, which is out of scope for this example. See the existing CKV_AWS_174 skip on this resource."
  #checkov:skip=CKV2_AWS_47: "WAF protection is not attached to this distribution per the existing CKV_AWS_68 skip on this resource; AMR for Log4j is not applicable."
  #checkov:skip=CKV2_AWS_32: "Response headers policy is configured by aws_cloudfront_response_headers_policy.landing_page and referenced via response_headers_policy_id in the default_cache_behavior; checkov's static analysis does not always trace count-indexed associations across separate resources (see bridgecrewio/checkov#2327)."
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
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-landing-page"
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.landing_page[0].id

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
