<!-- BEGIN_TF_DOCS -->
# Transfer Web App Module

This module creates web application resources for AWS Transfer Family.

## Overview

This module creates and configures a Transfer Family web app and related dependencies:

- IAM Identity Center organizational or account instance integration
- S3 Access Grants instance and locations management
- S3 Access Grants creation for fine-grained permissions
- Transfer Family web app provisioning, configuration, and customization

## Features

- **Browser-based interface** providing secure access to Amazon S3 data
- **Authentication** through AWS IAM Identity Center, supporting existing identity provider federation, multi-factor authentication
- **Granular permission management** through S3 Access Grants for user and group-level access control with configurable paths and permissions
- **KMS encryption support** for S3 buckets using SSE-KMS encryption
- **Built-in compliance** including HIPAA eligibility, PCI DSS compliance, SOC 1, 2, and 3, and ISO certifications
- **Customization options** including logo, favicon, and personalized browser page title
- **Flexible S3 Access Grants configuration** supporting new or existing instances and locations
- **Flexible IAM role configuration** supporting new or existing IAM roles

## Quick Start

```hcl
module "transfer_web_app" {
  source = "aws-ia/transfer-family/aws//modules/transfer-web-app"

  # Required Identity Center Configuration
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  identity_store_id           = "d-1234567890"

  # Identity Center Users and Groups
  identity_center_users = [
    {
      username = "admin"
      access_grants = [{
        s3_path    = "bucket/*"
        permission = "READWRITE"
      }]
    }
  ]

  identity_center_groups = [
    {
      group_name = "Analysts"
      access_grants = [{
        s3_path    = "bucket/*"
        permission = "READ"
      }]
    }
  ]

  tags = {
    Environment = "Demo"
    Project     = "File Portal"
  }
}
```

## S3 Path Examples

Access grants support various path patterns:

- `bucket/*` - All objects in the bucket
- `bucket/reports*` - Prefix within a bucket
- `bucket/data/logs*` - Prefix within prefix
- `bucket/data/file.txt` - Specific object

## Important Configuration Notes

### Same S3 Bucket Region Requirements
S3 buckets referenced in access grants must be located in the same AWS region where this module is deployed.

### S3 CORS Configuration
When using the Transfer Web App with S3 buckets, you must configure CORS (Cross-Origin Resource Sharing) on your S3 buckets to allow the web app to access the data. The `AllowedOrigins` in your S3 bucket CORS policy must include the URL of the newly created web app, which can be obtained from the module's `web_app_endpoint` output.

For detailed CORS configuration requirements, see the [AWS Transfer Family documentation](https://docs.aws.amazon.com/transfer/latest/userguide/access-grant-cors.html).

## S3 Access Grants Configuration

The module supports two configuration modes for S3 Access Grants:

### 1. Create New Instance and Location for All Buckets (Default - Recommended)
```hcl
# Creates new instance and location with scope for all buckets (default)
s3_access_grants_location_new = "s3://"  # Default value - recommended approach
```

### 2. Use Existing Instance and Location
```hcl
# Uses existing instance and location
# IMPORTANT: Existing S3 Access Grants instance must be associated with
# IAM Identity Center before creating access grants
s3_access_grants_instance_id         = "instance-id"
s3_access_grants_location_existing   = "location-id"
s3_access_grants_location_new        = null  # Skip location creation
```

For more information about S3 Access Grants locations, see the [AWS documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants-location-register.html).

## IAM Role Configuration

The module supports two configuration modes for IAM roles:

### 1. Create New IAM Role (Default)
```hcl
# Creates new IAM role with S3 Access Grants permissions (default)
iam_role_name = "transfer-web-app-role"  # Customize role name if needed
```

### 2. Use Existing IAM Role
```hcl
# Uses existing IAM role - must have S3 Access Grants permissions
existing_web_app_iam_role_arn = "arn:aws:iam::123456789012:role/existing-web-app-role"
```

**Important**: When using an existing IAM role, ensure it has the necessary S3 Access Grants permissions:
- `s3:GetDataAccess`
- `s3:ListCallerAccessGrants`
- `s3:ListAccessGrantsInstances`

## Key Variables

### Required Variables
- `identity_center_instance_arn` - ARN of Identity Center instance
- `identity_store_id` - ID of Identity Center identity store

### Optional Variables

#### Identity Center Configuration
- `identity_center_users` - List of users with access grants configuration (default: `[]`)
- `identity_center_groups` - List of groups with access grants configuration (default: `[]`)

#### S3 Access Grants Configuration
- `s3_access_grants_instance_id` - ID of existing S3 Access Grants instance (default: `null` - creates new)
- `s3_access_grants_location_new` - Location scope for new location (default: `"s3://"` for all buckets, `null` to skip creation)
- `s3_access_grants_location_existing` - ID of existing location (default: `null`, requires `s3_access_grants_instance_id` for non-null)
- `s3_access_grants_location_iam_role_arn` - ARN of existing IAM role for location (default: `null` - creates new)

#### IAM Configuration
- `existing_web_app_iam_role_arn` - ARN of existing IAM role for web app (default: `null` - creates new)
- `iam_role_name` - Name for IAM role used by web app when creating new role (default: `"transfer-web-app-role"`)

#### Web App Customization
- `logo_file` - Path to logo file for branding (default: `null`)
- `favicon_file` - Path to favicon file (default: `null`)
- `custom_title` - Custom browser page title (default: `null`)
- `provisioned_units` - Number of provisioned web app units (default: `1`). One web app unit allows web app activity from up to 250 unique sessions per 5 minute period.
  When creating a web app, you provision how many units you will need based on your expected peak workload volumes.
  Changing your web app units will have an impact on your billing.
  For more information, see [AWS Transfer Family Pricing](https://aws.amazon.com/aws-transfer-family/pricing/)

#### Tags
- `tags` - Map of tags to assign to resources (default: `{}`)

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.16.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.16.0 |

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
| [aws_s3control_access_grants_location.access_grants_location](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_location) | resource |
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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the Identity Center instance (required) | `string` | n/a | yes |
| <a name="input_identity_store_id"></a> [identity\_store\_id](#input\_identity\_store\_id) | ID of the Identity Store (required) | `string` | n/a | yes |
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `null` | no |
| <a name="input_existing_web_app_iam_role_arn"></a> [existing\_web\_app\_iam\_role\_arn](#input\_existing\_web\_app\_iam\_role\_arn) | ARN of an existing IAM role to use for the Transfer web app. If not provided, a new role will be created | `string` | `null` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `null` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name for the IAM role used by the Transfer web app (only used when iam\_role\_arn is not provided) | `string` | `"transfer-web-app-role"` | no |
| <a name="input_identity_center_groups"></a> [identity\_center\_groups](#input\_identity\_center\_groups) | List of groups to assign to the web app | <pre>list(object({<br/>    group_name = string<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_identity_center_users"></a> [identity\_center\_users](#input\_identity\_center\_users) | List of users to assign to the web app | <pre>list(object({<br/>    username = string<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `null` | no |
| <a name="input_provisioned_units"></a> [provisioned\_units](#input\_provisioned\_units) | Number of provisioned web app units | `number` | `1` | no |
| <a name="input_s3_access_grants_instance_id"></a> [s3\_access\_grants\_instance\_id](#input\_s3\_access\_grants\_instance\_id) | ID of the S3 Access Grants instance to use. If not provided, a new instance will be created | `string` | `null` | no |
| <a name="input_s3_access_grants_location_existing"></a> [s3\_access\_grants\_location\_existing](#input\_s3\_access\_grants\_location\_existing) | ID of an existing S3 Access Grants location to use. If provided, no new location will be created and s3\_access\_grants\_instance\_id must be specified | `string` | `null` | no |
| <a name="input_s3_access_grants_location_iam_role_arn"></a> [s3\_access\_grants\_location\_iam\_role\_arn](#input\_s3\_access\_grants\_location\_iam\_role\_arn) | ARN of an existing IAM role to use for the S3 Access Grants location. If not provided, a new role will be created | `string` | `null` | no |
| <a name="input_s3_access_grants_location_new"></a> [s3\_access\_grants\_location\_new](#input\_s3\_access\_grants\_location\_new) | S3 location scope for creating a new access grants location. Set to 's3://' (default) to create a location for all buckets, or null to skip location creation | `string` | `"s3://"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_grants_instance_arn"></a> [access\_grants\_instance\_arn](#output\_access\_grants\_instance\_arn) | The ARN of the S3 Access Grants instance |
| <a name="output_access_grants_instance_id"></a> [access\_grants\_instance\_id](#output\_access\_grants\_instance\_id) | The ID of the S3 Access Grants instance |
| <a name="output_access_grants_location_role_arn"></a> [access\_grants\_location\_role\_arn](#output\_access\_grants\_location\_role\_arn) | The ARN of the IAM role used by S3 Access Grants location (created or provided) |
| <a name="output_access_grants_location_role_name"></a> [access\_grants\_location\_role\_name](#output\_access\_grants\_location\_role\_name) | The name of the IAM role used by S3 Access Grants location (only available if created by module) |
| <a name="output_application_arn"></a> [application\_arn](#output\_application\_arn) | The ARN of the Identity Center application for the Transfer web app |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role used by the Transfer web app |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role used by the Transfer web app (only available when role is created by module) |
| <a name="output_web_app_arn"></a> [web\_app\_arn](#output\_web\_app\_arn) | The ARN of the Transfer web app |
| <a name="output_web_app_endpoint"></a> [web\_app\_endpoint](#output\_web\_app\_endpoint) | The web app endpoint URL for access and CORS configuration |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | The ID of the Transfer web app |
<!-- END_TF_DOCS -->