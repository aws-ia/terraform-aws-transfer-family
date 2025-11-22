# Cognito Hosted UI Module

This module creates an AWS Cognito User Pool with Managed Login (Hosted UI v2) and optionally deploys a CloudFront-backed landing page for authentication flows.

## Features

- **Cognito User Pool** with configurable password policies
- **Managed Login (Hosted UI v2)** with customizable branding
- **App Client** configured for OAuth 2.0 authorization code flow
- **Optional Landing Page** with CloudFront distribution for callback handling
- **Secure S3 hosting** with Origin Access Control (OAC)

## Usage

### Basic Usage

```hcl
module "cognito" {
  source = "./cognito-hosted-ui"

  user_pool_name = "my-app-users"
  domain_prefix  = "my-app-auth"  # Must be globally unique
  app_client_name = "my-app-client"

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

### With Landing Page

```hcl
module "cognito" {
  source = "./cognito-hosted-ui"

  user_pool_name = "my-app-users"
  domain_prefix  = "my-app-auth"
  
  create_landing_page    = true
  landing_page_template  = "${path.module}/landing.html"
  
  tags = {
    Environment = "production"
  }
}
```

### With Custom Branding

```hcl
module "cognito" {
  source = "./cognito-hosted-ui"

  user_pool_name = "my-app-users"
  domain_prefix  = "my-app-auth"
  
  branding_settings = "${path.module}/cognito-branding.json"
  
  tags = {
    Environment = "production"
  }
}
```

### Without Landing Page

```hcl
module "cognito" {
  source = "./cognito-hosted-ui"

  user_pool_name = "my-app-users"
  domain_prefix  = "my-app-auth"
  
  create_landing_page = false  # No landing page, configure callback URLs manually after creation
  
  tags = {
    Environment = "production"
  }
}
```

## Landing Page Template

The landing page template is an HTML file that can use the following variables:

- `${user_pool_id}` - Cognito User Pool ID
- `${client_id}` - App Client ID
- `${region}` - AWS Region
- `${cognito_domain}` - Cognito domain prefix

A complete example template with OAuth callback handling is available in `examples/complete/landing.html`.

Minimal template structure:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Login</title>
</head>
<body>
    <script>
        const userPoolId = '${user_pool_id}';
        const clientId = '${client_id}';
        const region = '${region}';
        const cognitoDomain = '${cognito_domain}';
        
        // Your authentication logic here
    </script>
</body>
</html>
```

## Branding Settings

The branding settings file should be a JSON file following the AWS Cognito Managed Login branding schema. See AWS documentation for the complete schema.

An example branding configuration is available in `examples/complete/cognito-branding.json`.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

The AWS provider version 5.0 or higher is required for Managed Login v2 support.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| user_pool_name | Name of the Cognito User Pool | `string` | n/a | yes |
| domain_prefix | Domain prefix for Cognito hosted UI (must be globally unique) | `string` | n/a | yes |
| app_client_name | Name of the Cognito app client | `string` | `"app-client"` | no |
| branding_settings | Path to the cognito-branding.json file for Managed Login branding | `string` | `null` | no |
| landing_page_template | Path to the landing page HTML template file (required if create_landing_page is true) | `string` | `null` | no |
| create_landing_page | Whether to create the landing page with CloudFront distribution | `bool` | `true` | no |
| landing_page_bucket_name | Name for the S3 bucket hosting the landing page. If not provided, uses domain_prefix | `string` | `""` | no |
| password_policy | Password policy configuration | `object` | See below | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

### Password Policy Default

```hcl
{
  minimum_length                   = 8
  require_lowercase                = true
  require_numbers                  = true
  require_symbols                  = true
  require_uppercase                = true
  temporary_password_validity_days = 7
}
```

## Outputs

| Name | Description |
|------|-------------|
| user_pool_id | ID of the Cognito User Pool |
| user_pool_arn | ARN of the Cognito User Pool |
| user_pool_endpoint | Endpoint of the Cognito User Pool |
| app_client_id | ID of the Cognito User Pool Client |
| cognito_domain | Cognito domain prefix |
| cognito_domain_url | Full Cognito hosted UI URL |
| landing_page_bucket_id | ID of the S3 bucket hosting the landing page |
| landing_page_bucket_arn | ARN of the S3 bucket hosting the landing page |
| cloudfront_distribution_id | ID of the CloudFront distribution |
| cloudfront_distribution_arn | ARN of the CloudFront distribution |
| cloudfront_domain_name | Domain name of the CloudFront distribution |
| cloudfront_url | Full URL of the CloudFront distribution |

## Notes

- The `domain_prefix` must be globally unique across all AWS accounts
- **If `create_landing_page` is `true`, you MUST provide `landing_page_template`**
- Callback and logout URLs are automatically set to the CloudFront distribution URL when `create_landing_page` is `true`
- If `create_landing_page` is `false`, the app client will have empty callback URLs (you'll need to configure them manually or via another resource)
- Changes to the branding settings file are automatically detected by Terraform
- The landing page uses CloudFront with Origin Access Control (OAC) for secure S3 access
