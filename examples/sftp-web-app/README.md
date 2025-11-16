<!-- BEGIN_TF_DOCS -->
# SFTP Web App Example

This example demonstrates how to deploy an AWS Transfer Family Web App with integrated Identity Center authentication, S3 Access Grants, and comprehensive audit logging.

## Architecture

This example creates:

- **Transfer Family Web App**: Browser-based interface for secure S3 file access
- **Identity Center Integration**: SSO authentication with groups and users
- **S3 Access Grants**: Fine-grained permissions with configurable paths and permissions
- **S3 Storage**: Encrypted bucket with versioning and public access blocking
- **CloudTrail Audit**: Comprehensive logging with SNS notifications and KMS encryption
- **CORS Configuration**: Restricted to web app endpoint only for enhanced security

## Key Features

- **Flexible Permission Model**: Configurable access paths and permissions via variables
- **Mixed Access Control**: User-level and group-level permissions as needed
- **Secure Authentication**: Integration with AWS Identity Center for SSO
- **Compliance Ready**: CloudTrail logging with encryption and SNS notifications
- **Customizable**: Easy to modify users, groups, paths, and permissions through variables

## What Gets Deployed

### IAM Identity Center Resources
- **Groups**: **Analysts** group (default) with read-only permission
- **Users** (with email-based activation):
  - **admin** user (default) with read/write access via user-level permissions
  - **analyst** user (default) with read-only permission inherited from **Analysts** group
- **Group memberships**: Links users to appropriate groups

### Transfer Family Resources
- Web app with custom branding and Identity Center integration
- IAM roles with S3 Access Grants permissions
- S3 Access Grants instance (if not provided)
- Access grants locations and grants for role-based permissions

### Storage and Security
- S3 bucket with encryption, versioning, and public access blocking
- CORS configuration restricted to web app endpoint only
- CloudTrail with KMS encryption and SNS notifications
- KMS key for CloudTrail log encryption

## Usage

1. **Update terraform.tfvars**: Provide real email addresses and configure access paths/permissions
2. **Deploy**: Run `terraform apply` to create all resources
3. **User Activation**: Users will receive activation emails to set up their accounts
4. **Access**: Users can log in through the web app endpoint URL

## Permission Structure

- **Admin User**: Gets READWRITE access via user-level permissions (configurable via `access_path` and `permission`)
- **Analyst User**: Gets READ access via Analysts group membership (no user-level permissions)
- **Default Access Path**: `*` (entire bucket) - configurable per user/group

## Configuration Variables

### User Configuration
```hcl
users = {
  "admin" = {
    # ... user details ...
    access_path = "*"           # Optional: defaults to no user-level access
    permission  = "READWRITE"   # Optional: used when access_path is set
  }
  "analyst" = {
    # ... user details ...
    # No access_path/permission - inherits from group
  }
}
```

### Group Configuration
```hcl
groups = {
  "analysts" = {
    # ... group details ...
    access_path = "*"     # Optional: defaults to "*"
    permission  = "READ"  # Optional: defaults to "READWRITE"
  }
}
```

## Important Notes

- **Email Addresses**: Must be real and accessible for user activation
- **Identity Center**: Requires an existing Identity Center instance in your account
- **Permission Logic**: User-level permissions only created when `access_path` is defined
- **CORS Security**: Origins restricted to web app endpoint only (no wildcards)
- **Costs**: This example creates billable AWS resources
- **Cleanup**: Run `terraform destroy` to remove all created resources

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | v5.0.0 |
| <a name="module_transfer_web_app"></a> [transfer\_web\_app](#module\_transfer\_web\_app) | ../../modules/transfer-web-app | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.access_grants_location_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.access_grants_location_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_identitystore_group.groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_identitystore_group_membership.memberships](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group_membership) | resource |
| [aws_identitystore_user.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_user) | resource |
| [aws_kms_alias.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3control_access_grants_instance.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_instance) | resource |
| [aws_s3control_access_grants_location.location](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3control_access_grants_location) | resource |
| [aws_sns_topic.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.access_grants_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.access_grants_location_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssoadmin_instances.identity_center](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_grants_instance_arn"></a> [access\_grants\_instance\_arn](#input\_access\_grants\_instance\_arn) | ARN of the S3 Access Grants instance. If not provided, a new instance will be created | `string` | `null` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `"Company File Portal"` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `null` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Map of groups to create | <pre>map(object({<br/>    group_name  = string<br/>    description = string<br/>    members     = optional(list(string))<br/>    access_path = optional(string)<br/>    permission  = optional(string)<br/>  }))</pre> | <pre>{<br/>  "analysts": {<br/>    "access_path": "*",<br/>    "description": "Read access to files",<br/>    "group_name": "Analysts",<br/>    "members": [<br/>      "analyst"<br/>    ],<br/>    "permission": "READ"<br/>  }<br/>}</pre> | no |
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the Identity Center instance. If not provided, will use the first available instance | `string` | `null` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | <pre>{<br/>  "Environment": "Demo",<br/>  "Project": "Web App File Transfer Portal"<br/>}</pre> | no |
| <a name="input_users"></a> [users](#input\_users) | Map of users to create | <pre>map(object({<br/>    display_name = string<br/>    user_name    = string<br/>    given_name   = string<br/>    family_name  = string<br/>    email        = string<br/>    access_path  = optional(string)<br/>    permission   = optional(string)<br/>  }))</pre> | <pre>{<br/>  "admin": {<br/>    "access_path": "*",<br/>    "display_name": "Admin User",<br/>    "email": "admin@example.com",<br/>    "family_name": "User",<br/>    "given_name": "Admin",<br/>    "permission": "READWRITE",<br/>    "user_name": "admin"<br/>  },<br/>  "analyst": {<br/>    "display_name": "Analyst User",<br/>    "email": "analyst@example.com",<br/>    "family_name": "User",<br/>    "given_name": "Analyst",<br/>    "user_name": "analyst"<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_grants_instance_arn"></a> [access\_grants\_instance\_arn](#output\_access\_grants\_instance\_arn) | The ARN of the S3 Access Grants instance |
| <a name="output_cloudtrail_arn"></a> [cloudtrail\_arn](#output\_cloudtrail\_arn) | ARN of the CloudTrail for audit logging |
| <a name="output_created_groups"></a> [created\_groups](#output\_created\_groups) | Map of created Identity Store groups |
| <a name="output_created_users"></a> [created\_users](#output\_created\_users) | Map of created Identity Store users |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket for file storage |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket for file storage |
| <a name="output_web_app_access_endpoint"></a> [web\_app\_access\_endpoint](#output\_web\_app\_access\_endpoint) | The access endpoint URL for the Transfer web app |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | The ID of the Transfer web app |
<!-- END_TF_DOCS -->