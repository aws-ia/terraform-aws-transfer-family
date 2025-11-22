# Complete Transfer Family Web App Example

This example demonstrates a complete setup of AWS Transfer Family Web App with S3 Access Grants integration.

## What This Example Creates

1. **Transfer Family Web App** - Configured with IAM Identity Center authentication
2. **S3 Bucket** - Dedicated bucket for the web app with security best practices
3. **S3 Access Grants Instance** - Creates new instance if one doesn't already exist in the account
4. **S3 Access Grants Location** - Configured for the entire bucket scope
5. **Two Web App Users**:
   - User 1: Assigned with READWRITE access grant to `user/<username>/` folder
   - User 2: Assigned without access grants (demonstrates external access grant management)
6. **One Web App Group** - Assigned with READ access grant to `shared/` folder

## Architecture

```
Transfer Family Web App
├── S3 Bucket (demo-transfer-webapp-bucket)
│   ├── user/
│   │   └── claims.reviewer/  (READWRITE for user1)
│   └── shared/                (READ for Claims Team group)
│
├── S3 Access Grants Instance
│   └── Access Grants Location (s3://bucket/*)
│       ├── Grant: user1 → user/claims.reviewer/* (READWRITE)
│       └── Grant: Claims Team → shared/* (READ)
│
└── User/Group Assignments
    ├── claims.reviewer (USER role, with access grants)
    ├── john.doe (USER role, no access grants)
    └── Claims Team (USER role, with access grants)
```

## Prerequisites

Before running this example, ensure you have:

1. **IAM Identity Center** configured in your AWS account
2. **Users created** in Identity Center:
   - `claims.reviewer` (or customize via `user1_username` variable)
   - `john.doe` (or customize via `user2_username` variable)
3. **Group created** in Identity Center:
   - `Claims Team` (or customize via `group_name` variable)
4. **AWS credentials** configured with appropriate permissions

## Usage

1. Create a `terraform.tfvars` file:

```hcl
identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
identity_store_id            = "d-1234567890"

# Optional: customize names
web_app_name    = "my-transfer-webapp"
bucket_name     = "my-transfer-webapp-bucket"
user1_username  = "claims.reviewer"
user2_username  = "john.doe"
group_name      = "Claims Team"

# Optional: use existing Access Grants instance
# existing_access_grants_instance_arn = "arn:aws:s3:us-east-1:123456789012:access-grants/default"
```

2. Initialize Terraform:

```bash
terraform init
```

3. Review the plan:

```bash
terraform plan
```

4. Apply the configuration:

```bash
terraform apply
```

## Access Patterns

### User 1 (claims.reviewer)
- **Web App Access**: Yes (USER role)
- **S3 Access**: READWRITE to `s3://bucket/user/claims.reviewer/*`
- **Use Case**: Personal workspace for uploading and managing their own files

### User 2 (john.doe)
- **Web App Access**: Yes (USER role)
- **S3 Access**: Managed externally (not through this module)
- **Use Case**: Demonstrates scenarios where access grants are managed through other systems or processes

### Group (Claims Team)
- **Web App Access**: Yes (USER role for all group members)
- **S3 Access**: READ to `s3://bucket/shared/*`
- **Use Case**: Shared read-only access to common resources

## Key Features Demonstrated

1. **Conditional Resource Creation**: Access Grants instance is created only if it doesn't already exist
2. **Flexible Access Grant Management**: Shows both managed and unmanaged access grant patterns
3. **Path-based Permissions**: Different folders with different permission levels
4. **Group-based Access**: Leveraging Identity Center groups for team access
5. **Security Best Practices**: Bucket encryption, versioning, and public access blocking

## Outputs

After applying, you'll receive:

- `web_app_endpoint` - URL to access the Transfer Family Web App
- `bucket_name` - Name of the created S3 bucket
- `user1_folder_path` - S3 path for user1's personal folder
- `shared_folder_path` - S3 path for the shared folder
- Access grant and assignment details

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: Ensure the S3 bucket is empty before destroying, or set `force_destroy = true` on the bucket resource.

## Customization

You can customize this example by:

- Changing user/group names via variables
- Adding more users or groups
- Modifying access grant permissions (READ, WRITE, READWRITE)
- Adjusting folder paths
- Using an existing S3 bucket instead of creating a new one
- Configuring VPC endpoint access instead of public access

## Notes

- Users and groups must exist in IAM Identity Center before running this example
- Access grants require the S3 Access Grants feature to be available in your region
- The first user demonstrates managed access grants through the module
- The second user demonstrates the pattern for external access grant management
