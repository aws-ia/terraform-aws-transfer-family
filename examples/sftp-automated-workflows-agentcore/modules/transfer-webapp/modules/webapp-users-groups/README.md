# Transfer Family Web App Users and Groups Submodule

This submodule manages user and group assignments to Transfer Family Web Apps with optional S3 Access Grants.

## Features

- Automatic Identity Store ID discovery from Identity Center
- User and group lookups by username/group name
- Identity Center application assignments
- Optional S3 Access Grants for fine-grained access control
- Support for DIRECTORY_USER and DIRECTORY_GROUP grantee types

## Usage

### With Access Grants

```hcl
module "webapp_users" {
  source = "./transfer-webapp/modules/webapp-users-groups"

  web_app_arn                = "arn:aws:transfer:us-east-1:123456789012:web-app/w-1234567890abcdef"
  access_grants_instance_arn = "arn:aws:s3:us-east-1:123456789012:access-grants/default"

  users = [
    {
      username = "claims.reviewer"
      access_grants = [
        {
          location_id = "ag-loc-1234567890abcdef"
          path        = "user/claims.reviewer/*"
          permission  = "READWRITE"
        }
      ]
    }
  ]

  groups = [
    {
      group_name = "Claims Team"
      access_grants = [
        {
          location_id = "ag-loc-1234567890abcdef"
          path        = "shared/*"
          permission  = "READ"
        }
      ]
    }
  ]
}
```

### Without Access Grants

```hcl
module "webapp_users" {
  source = "./transfer-webapp/modules/webapp-users-groups"

  web_app_arn = "arn:aws:transfer:us-east-1:123456789012:web-app/w-1234567890abcdef"

  users = [
    {
      username      = "john.doe"
      access_grants = null
    }
  ]

  groups = [
    {
      group_name    = "Admins"
      access_grants = null
    }
  ]
}
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0
- AWSCC Provider >= 0.15.0
- IAM Identity Center configured
- Users and groups must exist in Identity Center

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| web_app_arn | ARN of the Transfer Family Web App | string | - | yes |
| access_grants_instance_arn | ARN of S3 Access Grants instance | string | null | no |
| users | List of users to assign | list(object) | [] | no |
| groups | List of groups to assign | list(object) | [] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

### User Object Structure

```hcl
{
  username = string
  access_grants = optional(list(object({
    location_id = string
    path        = string
    permission  = string  # READ, WRITE, or READWRITE
  })))
}
```

### Group Object Structure

```hcl
{
  group_name = string
  access_grants = optional(list(object({
    location_id = string
    path        = string
    permission  = string  # READ, WRITE, or READWRITE
  })))
}
```

## Outputs

| Name | Description |
|------|-------------|
| user_assignments | Map of username to assignment details |
| group_assignments | Map of group name to assignment details |
| user_access_grants | Map of user access grants |
| group_access_grants | Map of group access grants |

## How It Works

1. **Identity Store Discovery**: Automatically retrieves Identity Store ID from Identity Center
2. **User/Group Lookup**: Looks up users by username and groups by display name to get their IDs
3. **Application Assignment**: Assigns users/groups to the web app via Identity Center application
4. **Access Grants** (optional): Creates S3 Access Grants for fine-grained path-based permissions

## Important Notes

- **Identity Store ID** is automatically discovered - no need to provide it
- **Users and groups** must already exist in Identity Center
- **Usernames** must match the UserName attribute in Identity Center
- **Group names** must match the DisplayName attribute in Identity Center
- **Access grants** are optional - omit or set to null to skip
- **Grantee types** use DIRECTORY_USER and DIRECTORY_GROUP (not IAM types)
- **Grantee identifiers** use just the user/group ID (not full ARN)

## Access Grant Permissions

- **READ**: Get and list operations
- **WRITE**: Put and delete operations
- **READWRITE**: Both read and write operations

## Example: Mixed Access Patterns

```hcl
module "webapp_users" {
  source = "./transfer-webapp/modules/webapp-users-groups"

  web_app_arn                = module.transfer_webapp.web_app_arn
  access_grants_instance_arn = module.transfer_webapp.access_grants_instance_arn

  users = [
    # User with personal folder access
    {
      username = "user1"
      access_grants = [
        {
          location_id = module.transfer_webapp.access_grants_location_id
          path        = "user/user1/*"
          permission  = "READWRITE"
        }
      ]
    },
    # User without access grants (managed elsewhere)
    {
      username      = "user2"
      access_grants = null
    }
  ]

  groups = [
    # Group with shared folder read access
    {
      group_name = "Viewers"
      access_grants = [
        {
          location_id = module.transfer_webapp.access_grants_location_id
          path        = "shared/*"
          permission  = "READ"
        }
      ]
    }
  ]
}
```

## Troubleshooting

- **User/group not found**: Verify the username/group name matches exactly in Identity Center
- **Access grant errors**: Ensure the location_id exists and the path is valid
- **Permission denied**: Check that the Access Grants instance ARN is correct
