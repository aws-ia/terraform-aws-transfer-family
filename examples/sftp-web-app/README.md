<!-- BEGIN_TF_DOCS -->
# SFTP Web App Example

This example demonstrates a complete deployment of AWS Transfer Family Web App with Identity Center authentication, S3 Access Grants, CloudTrail audit logging, and CORS configuration.

## What This Example Demonstrates

- **Complete end-to-end setup** from Identity Center users/groups to web-app deployment
- **CloudTrail integration** with KMS encryption and SNS notifications for audit logging
- **CORS configuration** restricted to the web app endpoint for security
- **Group-based permission model** showing access grants through group membership only
- **Automatic path prefixing** demonstrating how to construct full S3 paths from bucket names
- **Custom branding** with logo and favicon support

## What Gets Deployed

### Identity Center Resources
- Users: **admin** and **analyst**
- Groups: **Admins** (READWRITE) and **Analysts** (READ)
- Group memberships: admin → Admins, analyst → Analysts

### Transfer Web App
- Web app with Identity Center authentication and custom branding
- S3 Access Grants instance with default location scope ("s3://")
- Access grants for configured groups

### Storage and Audit
- S3 bucket with encryption, versioning, and public access blocking
- CORS configuration restricted to web app endpoint
- CloudTrail with KMS encryption and SNS notifications
- Dedicated S3 bucket for CloudTrail logs

## Usage

1. **Configure variables**: Provide real email addresses for user activation
2. **Deploy**: Run `terraform apply`
3. **User Activation**: Users receive activation emails to set up accounts
4. **Access**: Log in through the web app endpoint URL

## Permission Structure

This example uses group-based permissions only:

- **Admin user**: Gets READWRITE access through **Admins** group membership
- **Analyst user**: Gets READ access through **Analysts** group membership

S3 paths are automatically prefixed with the bucket name:
```hcl
s3_path = "/*"  # Becomes "bucket-name/*" in the module call
```

## Configuration Variables

### Required Variables
None - all variables have defaults

### Optional Variables with Defaults

#### AWS Configuration
- `aws_region` (default: `"us-east-1"`) - AWS region for deployment
- `identity_center_instance_arn` (default: `null`) - ARN of Identity Center instance, uses first available if not specified
- `s3_access_grants_instance_id` (default: `null`) - ID of existing S3 Access Grants instance, creates new if not specified

#### User Configuration
- `users` (default: admin and analyst users) - Map of users to create with display names, emails, etc.

#### Group Configuration  
- `groups` (default: admins and analysts groups) - Map of groups with members and access grants

#### Web App Customization
- `logo_file` (default: `"anycompany-logo.png"`) - Path to logo file for web app branding
- `favicon_file` (default: `"favicon.png"`) - Path to favicon file for web app
- `custom_title` (default: `"AnyCompany Financial Solutions"`) - Custom title for the web app

#### Resource Tagging
- `tags` (default: Environment="Demo", Project="Web App File Transfer Portal") - Tags to apply to all resources

### Example User Configuration
```hcl
users = {
  "admin" = {
    display_name = "Admin User"
    user_name    = "admin"
    first_name   = "Admin"
    last_name    = "User"
    email        = "admin@example.com"
  }
}
# Note: Access is granted through group membership, not direct user access grants
```

### Example Group Configuration
```hcl
groups = {
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
```

## S3 Path Examples

Supported path patterns (auto-prefixed with bucket name in this example):

- `/*` - All objects
- `/reports*` - Prefix within bucket
- `/data/logs*` - Nested prefix
- `/file.txt` - Specific object

## Important Notes

- **Email Addresses**: Must be real for user activation
- **Identity Center**: Requires existing instance in your account
- **Group-Based Access**: All permissions granted through group membership for better security management
- **CloudTrail**: Logs all S3 data events on the web app bucket
- **CORS**: Restricted to web app endpoint only (no wildcards)
- **Custom Branding**: Logo and favicon files should be placed in the example directory
- **Costs**: Creates billable AWS resources
- **Cleanup**: Run `terraform destroy` to remove all resources

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
| [aws_cloudtrail.web_app_audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_identitystore_group.groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_identitystore_group_membership.memberships](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group_membership) | resource |
| [aws_identitystore_user.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_user) | resource |
| [aws_kms_alias.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_s3_bucket.cloudtrail_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_policy.cloudtrail_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_sns_topic.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.cloudtrail_notifications](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssoadmin_instances.identity_center](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `"AnyCompany Financial Solutions"` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `"favicon.png"` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Map of groups to create | <pre>map(object({<br/>    group_name  = string<br/>    description = string<br/>    members     = optional(list(string))<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | <pre>{<br/>  "admins": {<br/>    "access_grants": [<br/>      {<br/>        "permission": "READWRITE",<br/>        "s3_path": "/*"<br/>      }<br/>    ],<br/>    "description": "Read and write access to files",<br/>    "group_name": "Admins",<br/>    "members": [<br/>      "admin"<br/>    ]<br/>  },<br/>  "analysts": {<br/>    "access_grants": [<br/>      {<br/>        "permission": "READ",<br/>        "s3_path": "/*"<br/>      }<br/>    ],<br/>    "description": "Read access to files",<br/>    "group_name": "Analysts",<br/>    "members": [<br/>      "analyst"<br/>    ]<br/>  }<br/>}</pre> | no |
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the Identity Center instance. If not provided, will use the first available instance | `string` | `null` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `"anycompany-logo-small.png"` | no |
| <a name="input_s3_access_grants_instance_id"></a> [s3\_access\_grants\_instance\_id](#input\_s3\_access\_grants\_instance\_id) | ID of the S3 Access Grants instance. If not provided, a new instance will be created | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | <pre>{<br/>  "Environment": "Demo",<br/>  "Project": "Web App File Transfer Portal"<br/>}</pre> | no |
| <a name="input_users"></a> [users](#input\_users) | Map of users to create | <pre>map(object({<br/>    display_name = string<br/>    user_name    = string<br/>    first_name   = string<br/>    last_name    = string<br/>    email        = string<br/>    access_grants = optional(list(object({<br/>      s3_path    = string<br/>      permission = string<br/>    })))<br/>  }))</pre> | <pre>{<br/>  "admin": {<br/>    "display_name": "Admin User",<br/>    "email": "admin@example.com",<br/>    "first_name": "Admin",<br/>    "last_name": "User",<br/>    "user_name": "admin"<br/>  },<br/>  "analyst": {<br/>    "display_name": "Analyst User",<br/>    "email": "analyst@example.com",<br/>    "first_name": "Analyst",<br/>    "last_name": "User",<br/>    "user_name": "analyst"<br/>  }<br/>}</pre> | no |

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