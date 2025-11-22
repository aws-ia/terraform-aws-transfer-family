# Transfer Family Web App Terraform Module

This module provisions AWS Transfer Family Web Apps with S3 Access Grants integration for fine-grained access control. The module uses a submodule architecture to support multiple S3 buckets/locations per web app.

## Features

- **Transfer Family Web App** with IAM Identity Center integration
- **Multiple S3 Locations** - Support for multiple buckets per web app via submodules
- **Flexible Bucket Management** - Create new buckets or use existing ones
- **S3 Access Grants** - Uses existing instance or default instance ARN
- **User & Group Assignments** - Assign Identity Center users/groups with granular permissions
- **Security Best Practices** - Encryption, versioning, CORS, and least-privilege IAM

## Architecture

The module consists of three components:

1. **Main Module** (`transfer-webapp`) - Creates the Transfer Family Web App
2. **Location Submodule** (`modules/webapp-location`) - Manages S3 buckets and Access Grants locations
3. **Users/Groups Submodule** (`modules/webapp-users-groups`) - Assigns users/groups with access grants

## Quick Start

### Single Bucket Setup

```hcl
# Create S3 Access Grants instance (only one per account)
resource "aws_s3control_access_grants_instance" "main" {
  identity_center_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
}

# Create the web app
module "transfer_webapp" {
  source = "./transfer-webapp"

  web_app_name                 = "my-webapp"
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  access_grants_instance_arn   = aws_s3control_access_grants_instance.main.access_grants_instance_arn
}

# Create a location with a new bucket
module "uploads_location" {
  source = "./transfer-webapp/modules/webapp-location"
  
  location_name              = "uploads"
  create_bucket              = true
  bucket_name                = "my-uploads-bucket"
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn
  cors_allowed_origins       = [module.transfer_webapp.web_app_endpoint]
}

# Assign users with access grants
module "webapp_users" {
  source = "./transfer-webapp/modules/webapp-users-groups"

  web_app_arn                = module.transfer_webapp.web_app_arn
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn

  users = [
    {
      username = "john.doe"
      access_grants = [
        {
          location_id = module.uploads_location.location_id
          path        = "user/john.doe/*"
          permission  = "READWRITE"
        }
      ]
    }
  ]
}
```

### Multiple Buckets Setup

```hcl
# Create S3 Access Grants instance (only one per account)
resource "aws_s3control_access_grants_instance" "main" {
  identity_center_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
}

# Create the web app
module "transfer_webapp" {
  source = "./transfer-webapp"

  web_app_name                 = "my-webapp"
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
  access_grants_instance_arn   = aws_s3control_access_grants_instance.main.access_grants_instance_arn
}

# Location 1: New bucket for uploads
module "uploads_location" {
  source = "./transfer-webapp/modules/webapp-location"
  
  location_name              = "uploads"
  create_bucket              = true
  bucket_name                = "my-uploads-bucket"
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn
  cors_allowed_origins       = [module.transfer_webapp.web_app_endpoint]
}

# Location 2: Existing bucket for shared documents
module "shared_location" {
  source = "./transfer-webapp/modules/webapp-location"
  
  location_name              = "shared-docs"
  create_bucket              = false
  bucket_name                = "existing-shared-bucket"
  bucket_prefix              = "documents/"
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn
}

# Assign users with access to multiple locations
module "webapp_users" {
  source = "./transfer-webapp/modules/webapp-users-groups"

  web_app_arn                = module.transfer_webapp.web_app_arn
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn

  users = [
    {
      username = "john.doe"
      access_grants = [
        {
          location_id = module.uploads_location.location_id
          path        = "user/john.doe/*"
          permission  = "READWRITE"
        },
        {
          location_id = module.shared_location.location_id
          path        = "*"
          permission  = "READ"
        }
      ]
    },
    {
      username      = "jane.smith"
      access_grants = null  # Grants managed elsewhere
    }
  ]

  groups = [
    {
      group_name = "Reviewers"
      access_grants = [
        {
          location_id = module.shared_location.location_id
          path        = "*"
          permission  = "READ"
        }
      ]
    }
  ]
}
```

## Module Reference

### Main Module (`transfer-webapp`)

Creates the Transfer Family Web App.

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| web_app_name | Name of the Transfer Family Web App | string | - | yes |
| identity_center_instance_arn | ARN of the IAM Identity Center instance | string | - | yes |
| access_endpoint | Custom endpoint URL for the web app | string | null | no |
| access_grants_instance_arn | ARN of existing S3 Access Grants instance | string | - | yes |
| tags | Tags to apply to resources | map(string) | {} | no |

#### Outputs

| Name | Description |
|------|-------------|
| web_app_id | ID of the Transfer Family Web App |
| web_app_arn | ARN of the Transfer Family Web App |
| web_app_endpoint | Endpoint URL of the Web App |
| bearer_role_arn | ARN of the bearer role |
| access_grants_instance_arn | ARN of the Access Grants instance |

### Location Submodule (`modules/webapp-location`)

Manages S3 buckets and Access Grants locations.

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| location_name | Name for this location | string | - | yes |
| create_bucket | Whether to create a new S3 bucket | bool | true | no |
| bucket_name | Name of bucket (existing or new) | string | - | yes |
| bucket_prefix | Prefix for the S3 bucket path (must end with '/') | string | "" | no |
| access_grants_instance_arn | ARN of the Access Grants instance | string | - | yes |
| cors_allowed_origins | List of allowed origins for CORS | list(string) | [] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

#### Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the S3 bucket |
| bucket_arn | ARN of the S3 bucket |
| location_arn | ARN of the Access Grants location |
| location_id | ID of the Access Grants location |
| iam_role_arn | ARN of the IAM role for this location |
| s3_prefix_arn | S3 prefix ARN for this location |

### Users/Groups Submodule (`modules/webapp-users-groups`)

Assigns Identity Center users and groups to the web app with access grants.

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| web_app_arn | ARN of the Transfer Family Web App | string | - | yes |
| access_grants_instance_arn | ARN of Access Grants instance | string | null | no |
| users | List of users to assign | list(object) | [] | no |
| groups | List of groups to assign | list(object) | [] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

**User/Group Object Structure:**
```hcl
{
  username = "john.doe"  # or group_name for groups
  access_grants = [      # or null for no grants
    {
      location_id = "location-id"
      path        = "path/to/files/*"
      permission  = "READWRITE"  # READ, WRITE, or READWRITE
    }
  ]
}
```

#### Outputs

| Name | Description |
|------|-------------|
| user_assignments | Map of user assignments |
| group_assignments | Map of group assignments |
| user_access_grants | Map of user access grants |
| group_access_grants | Map of group access grants |

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- AWSCC Provider >= 0.15.0
- IAM Identity Center instance configured
- Identity Store with users and groups

## Important Notes

- **Access Grants Instance** - You must create an S3 Access Grants instance and provide its ARN. Only one instance can exist per AWS account
- **Users and Groups** - Must exist in IAM Identity Center before assignment
- **Permissions** - Can be READ, WRITE, or READWRITE
- **Identity Store ID** - Automatically discovered from Identity Center
- **CORS** - Only configured when creating new buckets and origins are specified
- **Bucket Prefixes** - Use to restrict access to specific folders within a bucket
- **Null Grants** - Set `access_grants = null` to assign users without managing their grants

## Security Features

- **S3 Buckets** - Public access blocked, encryption enabled, versioning enabled
- **CORS** - Restricted to web app endpoint only
- **IAM Roles** - Least-privilege policies with proper trust relationships
- **Access Grants** - Fine-grained, path-level access control
- **Identity Center** - Centralized authentication and authorization

## Examples

See the `examples/complete` directory for a full working example demonstrating:
- Multiple S3 locations (new and existing buckets)
- Users with access to multiple locations
- Users without managed access grants
- Group assignments with shared access

## Migration from Previous Version

If you're upgrading from the previous version, see [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md) for migration guidance.

## License

This module is released under the MIT License.
