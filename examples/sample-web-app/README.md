<!-- BEGIN_TF_DOCS -->
# Sample Web App Example

This example demonstrates a complete deployment of AWS Transfer Family Web App with IAM Identity Center authentication, S3 Access Grants, CloudTrail audit logging, and CORS configuration.

## What This Example Demonstrates

- **Complete end-to-end setup** from IAM Identity Center users/groups to web-app deployment
- **CloudTrail integration** with KMS encryption and SNS notifications for audit logging
- **CORS configuration** restricted to the web app endpoint for security
- **Flexible user/group management** supporting both test user and/or creation and imported existing users/groups
- **Automatic path prefixing** demonstrating how to construct full S3 paths from bucket names
- **Custom branding** with logo and favicon support

## What Gets Deployed

### Identity Center Resources (Optional)

- Users and groups (when `create_test_users_and_groups = true`)
- Group creation and group memberships for created users
- OR references to existing Identity Center users/groups (default mode)

### Transfer Web App

- Web app with Identity Center authentication and custom branding
- S3 Access Grants instance with default location scope ("s3://")
- Access grants for configured users and/or groups

### Storage and Audit

- S3 bucket with encryption, versioning, and public access blocking
- CORS configuration restricted to web app endpoint
- CloudTrail with KMS encryption and SNS notifications
- Dedicated S3 bucket for CloudTrail logs

## Usage

1. **Configure users/groups**: Choose between creating test users and/or groups or configuring existing ones
2. **Email addresses**: If creating new users, provide real email addresses for user activation
3. **Deploy**: Run `terraform apply`
4. **User Activation**: If creating new users, they receive activation emails to set up accounts
5. **Access**: Log in through the web app endpoint URL

## User and Group Management Options

This example supports two approaches for managing users and groups:

### Option 1: Create Test Users and Groups (Default: Disabled)

Set `create_test_users_and_groups = true` to have Terraform create new Identity Center users and groups:

- Creates users with email activation required
- Creates groups with specified descriptions and member assignments
- Automatically handles group memberships
- Ideal for demo environments or new Identity Center setups
- **Note**: When enabled, any configurations in `imported-users.tf` and `imported-groups.tf` will be ignored

### Option 2: Import Existing Users and Groups (Default: Enabled)

Configure existing Identity Center users/groups via `imported-users.tf` and `imported-groups.tf`:

- **imported-users.tf**: Reference existing users by username and assign individual access grants
- **imported-groups.tf**: Reference existing groups by name and assign group-level access grants
- Users and groups must already exist in Identity Center before deployment
- Ideal for production environments with established Identity Center configurations

S3 paths are automatically prefixed with the bucket name:

```hcl
s3_path = "/*"  # Becomes "bucket-name/*" in the module call
```

To switch modes, modify the `create_test_users_and_groups` variable and update the respective configuration files.

## Configuration Variables

### Required Variables

None - all variables have defaults

### Optional Variables with Defaults

#### AWS Configuration

- `aws_region` (default: `"us-east-1"`) - AWS region for deployment
- `identity_center_instance_arn` (default: `null`) - ARN of Identity Center instance (required if create\_identity\_center\_instance is false)
- `identity_store_id` (default: `null`) - ID of Identity Center identity store (required if create\_identity\_center\_instance is false)
- `create_identity_center_instance` (default: `false`) - Whether to create a new Identity Center instance (required if identity\_center\_instance\_arn and identity\_store\_id are null)
- `s3_access_grants_instance_id` (default: `null`) - ID of existing S3 Access Grants instance, creates new if not specified

#### User and Group Configuration

- `create_test_users_and_groups` (default: `false`) - Whether to create new users/groups or use existing ones
- `test_users` (default: admin and analyst users) - Map of users to create when `create_test_users_and_groups = true`
- `test_groups` (default: admins and analysts groups) - Map of groups to create when `create_test_users_and_groups = true`

#### Web App Customization

- `logo_file` (default: `"anycompany-logo-small.png"`) - Path to logo file for web app branding
- `favicon_file` (default: `"favicon.png"`) - Path to favicon file for web app
- `custom_title` (default: `"AnyCompany Financial Solutions"`) - Custom title for the web app

#### Resource Tagging

- `tags` (default: Name="Demo Web App File Transfer Portal", Environment="Demo", Project="Web App File Transfer Portal") - Tags to organize, search, and filter your web apps.

### Example Test User Configuration

```hcl
test_users = {
  "admin" = {
    display_name = "Admin User"
    user_name    = "admin"
    first_name   = "Admin"
    last_name    = "User"
    email        = "admin@example.com"
  }
}
# Note: Only used when create_test_users_and_groups = true
```

### Example Test Group Configuration

```hcl
test_groups = {
  "admins" = {
    group_name  = "Admins"
    description = "Read and write access to files"
    members     = ["admin"]
    access_grants = [{
      s3_path    = "/*"         # Auto-prefixed with bucket name
      permission = "READWRITE"
    }]
  }
}
# Note: Only used when create_test_users_and_groups = true
```

## S3 Path Examples

Supported path patterns (auto-prefixed with bucket name in this example):

- `/*` - All objects in the bucket
- `/reports*` - Prefix within bucket
- `/data/logs*` - Prefix within prefix
- `/data/file.txt` - Specific object

## Important Notes

- **Email Addresses**: Must be real for user activation when creating new users
- **Identity Center**: Requires existing instance in your account with `identity_center_instance_arn` and `identity_store_id` provided, or set `create_identity_center_instance = true` to create a new one
- **User/Group Management**: Choose between creating test users or importing existing ones via configuration files
- **CloudTrail**: Logs all S3 data events on the web app bucket
- **CORS**: Restricted to web app endpoint only (no wildcards)
- **Custom Branding**: Logo and favicon files should be placed in the example directory
- **Production Warning**: This example uses `force_destroy = true` on the CloudTrail logging S3 bucket for easy cleanup.
  This is NOT suitable for production as it will delete all audit logs when running `terraform destroy`.
  Remove this setting for production deployments.
- **Costs**: Creates billable AWS resources
- **Cleanup**: Run `terraform destroy` to remove all resources

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.16.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.16.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | >= 1.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | v5.0.0 |
| <a name="module_s3_bucket_cloudtrail_logs"></a> [s3\_bucket\_cloudtrail\_logs](#module\_s3\_bucket\_cloudtrail\_logs) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | v5.0.0 |
| <a name="module_transfer_web_app"></a> [transfer\_web\_app](#module\_transfer\_web\_app) | ../../modules/transfer-web-app | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudtrail.web_app_audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_cloudwatch_log_group.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.cloudtrail_cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudtrail_cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_identitystore_group.groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_identitystore_group_membership.memberships](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group_membership) | resource |
| [aws_identitystore_user.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_user) | resource |
| [aws_kms_alias.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_s3_bucket_cors_configuration.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_policy.cloudtrail_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_sns_topic.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [awscc_sso_instance.identity_center](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/sso_instance) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_create_identity_center_instance"></a> [create\_identity\_center\_instance](#input\_create\_identity\_center\_instance) | Whether to create a new IAM Identity Center account instance (required if identity\_center\_instance\_arn is null) | `bool` | `false` | no |
| <a name="input_create_test_users_and_groups"></a> [create\_test\_users\_and\_groups](#input\_create\_test\_users\_and\_groups) | Whether to create test users and groups | `bool` | `false` | no |
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `"AnyCompany Financial Solutions"` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `"favicon.png"` | no |
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the IAM Identity Center instance (required if create\_identity\_center\_instance is false) | `string` | `null` | no |
| <a name="input_identity_store_id"></a> [identity\_store\_id](#input\_identity\_store\_id) | ID of the Identity Store (required if create\_identity\_center\_instance is false) | `string` | `null` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `"anycompany-logo-small.png"` | no |
| <a name="input_s3_access_grants_instance_id"></a> [s3\_access\_grants\_instance\_id](#input\_s3\_access\_grants\_instance\_id) | ID of the S3 Access Grants instance. If not provided, a new instance will be created | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to organize, search, and filter your web apps. | `map(string)` | <pre>{<br/>  "Environment": "Demo",<br/>  "Name": "Demo Web App File Transfer Portal",<br/>  "Project": "Web App File Transfer Portal"<br/>}</pre> | no |
| <a name="input_test_groups"></a> [test\_groups](#input\_test\_groups) | Map of test groups to create | <pre>map(object({<br/>    group_name  = string<br/>    description = string<br/>    members     = list(string)<br/>    access_grants = list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    }))<br/>  }))</pre> | <pre>{<br/>  "admins": {<br/>    "access_grants": [<br/>      {<br/>        "permission": "READWRITE",<br/>        "s3_path": "/*"<br/>      }<br/>    ],<br/>    "description": "Read and write access to files",<br/>    "group_name": "Admins",<br/>    "members": [<br/>      "admin"<br/>    ]<br/>  },<br/>  "analysts": {<br/>    "access_grants": [<br/>      {<br/>        "permission": "READ",<br/>        "s3_path": "/*"<br/>      }<br/>    ],<br/>    "description": "Read access to files",<br/>    "group_name": "Analysts",<br/>    "members": [<br/>      "analyst"<br/>    ]<br/>  }<br/>}</pre> | no |
| <a name="input_test_users"></a> [test\_users](#input\_test\_users) | Map of test users to create. Note: The grants and access in this default value are being assigned through the created groups only. | <pre>map(object({<br/>    display_name = string<br/>    user_name    = string<br/>    first_name   = string<br/>    last_name    = string<br/>    email        = string<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | <pre>{<br/>  "admin": {<br/>    "display_name": "Admin User",<br/>    "email": "admin@example.com",<br/>    "first_name": "Admin",<br/>    "last_name": "User",<br/>    "user_name": "admin"<br/>  },<br/>  "analyst": {<br/>    "display_name": "Analyst User",<br/>    "email": "analyst@example.com",<br/>    "first_name": "Analyst",<br/>    "last_name": "User",<br/>    "user_name": "analyst"<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_grants_instance_arn"></a> [access\_grants\_instance\_arn](#output\_access\_grants\_instance\_arn) | The ARN of the S3 Access Grants instance |
| <a name="output_cloudtrail_arn"></a> [cloudtrail\_arn](#output\_cloudtrail\_arn) | ARN of the CloudTrail for audit logging |
| <a name="output_created_groups"></a> [created\_groups](#output\_created\_groups) | Map of created Identity Store groups |
| <a name="output_created_users"></a> [created\_users](#output\_created\_users) | Map of created Identity Store users |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket for file storage |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket for file storage |
| <a name="output_web_app_endpoint"></a> [web\_app\_endpoint](#output\_web\_app\_endpoint) | The web app endpoint URL for access and CORS configuration |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | The ID of the Transfer web app |
<!-- END_TF_DOCS -->