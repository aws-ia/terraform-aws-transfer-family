<!-- BEGIN_TF_DOCS -->
# Transfer Web App Module

This module creates web application resources for AWS Transfer Family.

## Overview

This module creates and configures a Transfer Family web app and related dependencies:

- IAM Identity Center organizational or account instance integration
- S3 Access Grants instance integration
- S3 Access Grants creation for fine-grained permissions
- Transfer Family web app provisioning, configuration, and customization
- Cross-Origin Resource Sharing (CORS) policies for S3 buckets
- Create a CloudFront distribution for custom URL
- Logging and monitoring via AWS CloudTrail

## Features

- **Browser-based interface** providing secure access to Amazon S3 data
- **Authentication** through AWS IAM Identity Center, supporting existing identity provider federation, multi-factor authentication
- **Granular permission management** through S3 Access Grants for user and group-level access control, folder and file-level permissions, and time-based access policies
- **Built-in compliance** including HIPAA eligibility, PCI DSS compliance, SOC 1, 2, and 3, and ISO certifications
- **Customization options** including logo, favicon, and personalized browser page title
- **Detailed audit trails** through CloudTrail capturing user authentication and data operations

## Quick Start

```hcl
module "transfer_web_app" {
  source = "aws-ia/transfer-family/aws//modules/transfer-web-app"

  # Basic configuration
  iam_role_name = "my-transfer-web-app-role"
  # S3 bucket for web app access
  s3_bucket_arn = "arn:aws:s3:::my-bucket"
  # Customization
  custom_title = "My Company File Portal"
  logo_file    = "path/to/logo.png"
  # Access grants
  create_access_grants = true
  access_grants = {
    "user1-read" = {
      location_scope     = "s3://my-bucket/user1/*"
      permission         = "READ"
      grantee_identifier = "arn:aws:iam::123456789012:user/user1"
    }
    "admin-full" = {
      location_scope     = "s3://my-bucket/*"
      permission         = "READWRITE"
      grantee_identifier = "arn:aws:iam::123456789012:user/admin"
    }
  }
  tags = {
    Environment = "Production"
    Project     = "File Portal"
  }
}
```

## Key Variables

### Required Variables
None - all variables have sensible defaults.

### Important Optional Variables

- `iam_role_name` - Name for the IAM role (default: "transfer-web-app-role")
- `s3_bucket_arn` - S3 bucket ARN for web app access
- `custom_title` - Custom title for the web app
- `logo_file` - Path to logo file for branding
- `favicon_file` - Path to favicon file
- `create_access_grants` - Enable S3 Access Grants creation (default: false)
- `access_grants` - Map of access grants to create for fine-grained permissions
- `enable_cors` - Enable CORS configuration for S3 bucket (default: true)
- `enable_cloudtrail` - Enable CloudTrail audit logging (default: true)
- `cloudtrail_sns_topic_arn` - SNS topic ARN for CloudTrail notifications
- `cloudtrail_kms_key_id` - KMS key ID for CloudTrail log encryption

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudtrail.audit_trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_iam_role.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_identitystore_group.groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_identitystore_group_membership.memberships](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group_membership) | resource |
| [aws_identitystore_user.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_user) | resource |
| [aws_s3_bucket.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.web_app_cors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_policy.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3control_access_grant.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grant) | resource |
| [aws_s3control_access_grants_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_instance) | resource |
| [aws_s3control_access_grants_location.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_location) | resource |
| [aws_transfer_web_app.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_web_app) | resource |
| [aws_transfer_web_app_customization.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_web_app_customization) | resource |
| [random_id.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role_transfer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudtrail_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssoadmin_instances.identity_center](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | ARN of the S3 bucket to grant access to via the web app | `string` | n/a | yes |
| <a name="input_access_grants"></a> [access\_grants](#input\_access\_grants) | Map of access grants to create | <pre>map(object({<br/>    location_scope     = string<br/>    permission         = optional(string, "READ")<br/>    s3_sub_prefix      = optional(string)<br/>    grantee_type       = optional(string, "IAM")<br/>    grantee_identifier = string<br/>  }))</pre> | `{}` | no |
| <a name="input_cloudtrail_kms_key_id"></a> [cloudtrail\_kms\_key\_id](#input\_cloudtrail\_kms\_key\_id) | KMS key ID for CloudTrail log encryption | `string` | `null` | no |
| <a name="input_cloudtrail_name"></a> [cloudtrail\_name](#input\_cloudtrail\_name) | Name for the CloudTrail | `string` | `"transfer-web-app-audit-trail"` | no |
| <a name="input_cloudtrail_s3_bucket_name"></a> [cloudtrail\_s3\_bucket\_name](#input\_cloudtrail\_s3\_bucket\_name) | S3 bucket name for CloudTrail logs. If not provided, a bucket will be created | `string` | `null` | no |
| <a name="input_cloudtrail_sns_topic_arn"></a> [cloudtrail\_sns\_topic\_arn](#input\_cloudtrail\_sns\_topic\_arn) | SNS topic ARN for CloudTrail notifications | `string` | `null` | no |
| <a name="input_cors_allowed_headers"></a> [cors\_allowed\_headers](#input\_cors\_allowed\_headers) | List of allowed headers for CORS | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_cors_allowed_methods"></a> [cors\_allowed\_methods](#input\_cors\_allowed\_methods) | List of allowed HTTP methods for CORS | `list(string)` | <pre>[<br/>  "GET",<br/>  "PUT",<br/>  "POST",<br/>  "DELETE",<br/>  "HEAD"<br/>]</pre> | no |
| <a name="input_cors_allowed_origins"></a> [cors\_allowed\_origins](#input\_cors\_allowed\_origins) | List of allowed origins for CORS | `list(string)` | <pre>[<br/>  "*"<br/>]</pre> | no |
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `null` | no |
| <a name="input_enable_cloudtrail"></a> [enable\_cloudtrail](#input\_enable\_cloudtrail) | Enable CloudTrail for audit logging of user authentication and data operations | `bool` | `true` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `null` | no |
| <a name="input_group_memberships"></a> [group\_memberships](#input\_group\_memberships) | Map of group memberships (group\_key -> list of user\_keys) | `map(list(string))` | `{}` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name for the IAM role used by the Transfer web app | `string` | `"transfer-web-app-role"` | no |
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the Identity Center instance. If not provided, will use the first available instance | `string` | `null` | no |
| <a name="input_identity_store_groups"></a> [identity\_store\_groups](#input\_identity\_store\_groups) | Map of Identity Store groups to create | <pre>map(object({<br/>    display_name = string<br/>    description  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_identity_store_users"></a> [identity\_store\_users](#input\_identity\_store\_users) | Map of Identity Store users to create | <pre>map(object({<br/>    display_name = string<br/>    user_name    = string<br/>    given_name   = string<br/>    family_name  = string<br/>    email        = string<br/>  }))</pre> | `{}` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `null` | no |
| <a name="input_provisioned_units"></a> [provisioned\_units](#input\_provisioned\_units) | Number of provisioned web app units | `number` | `1` | no |
| <a name="input_s3_access_grants_instance_id"></a> [s3\_access\_grants\_instance\_id](#input\_s3\_access\_grants\_instance\_id) | ID of the S3 Access Grants instance to use. If null, a new instance will be created | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_arn"></a> [application\_arn](#output\_application\_arn) | The ARN of the Identity Center application for the Transfer web app |
| <a name="output_cloudtrail_arn"></a> [cloudtrail\_arn](#output\_cloudtrail\_arn) | ARN of the CloudTrail for audit logging |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role used by the Transfer web app |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role used by the Transfer web app |
| <a name="output_identity_store_group_ids"></a> [identity\_store\_group\_ids](#output\_identity\_store\_group\_ids) | Map of Identity Store group names to their IDs |
| <a name="output_web_app_access_endpoint"></a> [web\_app\_access\_endpoint](#output\_web\_app\_access\_endpoint) | The access endpoint URL for the Transfer web app |
| <a name="output_web_app_arn"></a> [web\_app\_arn](#output\_web\_app\_arn) | The ARN of the Transfer web app |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | The ID of the Transfer web app |
<!-- END_TF_DOCS -->