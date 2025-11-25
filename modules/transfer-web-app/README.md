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
- Logging and monitoring via AWS CloudTrail

## Features

- **Browser-based interface** providing secure access to Amazon S3 data
- **Authentication** through AWS IAM Identity Center, supporting existing identity provider federation, multi-factor authentication
- **Granular permission management** through S3 Access Grants for user and group-level access control with configurable paths and permissions
- **Built-in compliance** including HIPAA eligibility, PCI DSS compliance, SOC 1, 2, and 3, and ISO certifications
- **Customization options** including logo, favicon, and personalized browser page title
- **Detailed audit trails** through CloudTrail capturing user authentication and data operations

## Quick Start

```hcl
module "transfer_web_app" {
  source = "aws-ia/transfer-family/aws//modules/transfer-web-app"

  # S3 Configuration
  s3_bucket_names = ["my-bucket"]

  # CORS Configuration - Restrict to web app only
  cors_allowed_origins = []  # Only web app endpoint will be allowed by default

  # Identity Center Configuration
  identity_center_users = [
    {
      username = "admin"
      access_grants = [{
        location_id = "location-id"
        path        = "*"
        permission  = "READWRITE"
      }]
    }
  ]

  identity_center_groups = [
    {
      group_name = "Analysts"
      access_grants = [{
        location_id = "location-id"
        path        = "*"
        permission  = "READ"
      }]
    }
  ]

  # CloudTrail Configuration
  enable_cloudtrail        = true
  cloudtrail_name         = "my-audit-trail"
  cloudtrail_kms_key_id   = "arn:aws:kms:region:account:key/key-id"

  tags = {
    Environment = "Demo"
    Project     = "File Portal"
  }
}
```

## Key Variables

### Required Variables
- `s3_bucket_names` - List of S3 bucket names to configure CORS for

### Important Optional Variables

- `identity_center_users` - List of users with access grants configuration
- `identity_center_groups` - List of groups with access grants configuration  
- `cors_allowed_origins` - List of allowed origins for CORS (default: [])
- `cors_allowed_methods` - List of allowed HTTP methods for CORS
- `cors_allowed_headers` - List of allowed headers for CORS
- `enable_cloudtrail` - Enable CloudTrail audit logging (default: false)
- `cloudtrail_name` - Name for the CloudTrail
- `cloudtrail_kms_key_id` - KMS key ID for CloudTrail log encryption
- `cloudtrail_sns_topic_arn` - SNS topic ARN for CloudTrail notifications
- `access_grants_location_arn` - ARN of existing S3 Access Grants location

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.access_grants_location](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.access_grants_location](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3control_access_grant.group_grants](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grant) | resource |
| [aws_s3control_access_grant.user_grants](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grant) | resource |
| [aws_s3control_access_grants_instance.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_instance) | resource |
| [aws_s3control_access_grants_location.all_buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_location) | resource |
| [aws_ssoadmin_application_assignment.groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_application_assignment) | resource |
| [aws_ssoadmin_application_assignment.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_application_assignment) | resource |
| [aws_transfer_web_app.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_web_app) | resource |
| [aws_transfer_web_app_customization.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_web_app_customization) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.access_grants_location_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.access_grants_location_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.assume_role_transfer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_identitystore_group.groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_group) | data source |
| [aws_identitystore_user.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_user) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3control_access_grants_locations.all_buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3control_access_grants_locations) | data source |
| [aws_ssoadmin_instances.identity_center](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_grants_instance_arn"></a> [access\_grants\_instance\_arn](#input\_access\_grants\_instance\_arn) | ARN of the S3 Access Grants instance (required if access grants are configured) | `string` | `null` | no |
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `null` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `null` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name for the IAM role used by the Transfer web app | `string` | `"transfer-web-app-role"` | no |
| <a name="input_identity_center_groups"></a> [identity\_center\_groups](#input\_identity\_center\_groups) | List of groups to assign to the web app | <pre>list(object({<br/>    group_name = string<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the Identity Center instance. If not provided, will use the first available instance | `string` | `null` | no |
| <a name="input_identity_center_users"></a> [identity\_center\_users](#input\_identity\_center\_users) | List of users to assign to the web app | <pre>list(object({<br/>    username = string<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `null` | no |
| <a name="input_provisioned_units"></a> [provisioned\_units](#input\_provisioned\_units) | Number of provisioned web app units | `number` | `1` | no |
| <a name="input_s3_access_grants_instance_id"></a> [s3\_access\_grants\_instance\_id](#input\_s3\_access\_grants\_instance\_id) | ID of the S3 Access Grants instance to use. If not provided, will use the first available instance | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_grants_instance_id"></a> [access\_grants\_instance\_id](#output\_access\_grants\_instance\_id) | The ID of the S3 Access Grants instance |
| <a name="output_application_arn"></a> [application\_arn](#output\_application\_arn) | The ARN of the Identity Center application for the Transfer web app |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role used by the Transfer web app |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role used by the Transfer web app |
| <a name="output_identity_store_group_ids"></a> [identity\_store\_group\_ids](#output\_identity\_store\_group\_ids) | Map of Identity Store group names to their IDs |
| <a name="output_web_app_access_endpoint"></a> [web\_app\_access\_endpoint](#output\_web\_app\_access\_endpoint) | The access endpoint URL for the Transfer web app |
| <a name="output_web_app_arn"></a> [web\_app\_arn](#output\_web\_app\_arn) | The ARN of the Transfer web app |
| <a name="output_web_app_endpoint"></a> [web\_app\_endpoint](#output\_web\_app\_endpoint) | The web app endpoint for CORS configuration |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | The ID of the Transfer web app |
<!-- END_TF_DOCS -->