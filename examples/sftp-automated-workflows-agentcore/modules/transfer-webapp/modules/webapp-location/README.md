# Transfer Webapp Location Module

This submodule creates an S3 Access Grants location for the Transfer Family web application. Each location represents a bucket (or bucket prefix) that the web app can access.

## Features

- Optional S3 bucket creation (or use existing bucket)
- Automatic IAM role and policy creation for Access Grants
- Support for bucket prefixes (e.g., specific folders)
- S3 Access Grants location registration

## Usage

### Create a new bucket

```hcl
module "uploads_location" {
  source = "./modules/webapp-location"
  
  location_name               = "uploads"
  create_bucket               = true
  bucket_name                 = "my-app-uploads"
  bucket_prefix               = "user-uploads/"
  access_grants_instance_arn  = aws_s3control_access_grants_instance.main.arn
}
```

### Use an existing bucket

```hcl
module "existing_location" {
  source = "./modules/webapp-location"
  
  location_name               = "existing-data"
  create_bucket               = false
  bucket_name                 = "existing-bucket-name"
  bucket_prefix               = "data/"
  access_grants_instance_arn  = aws_s3control_access_grants_instance.main.arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location_name | Name for this location (used in resource naming) | `string` | n/a | yes |
| create_bucket | Whether to create a new S3 bucket | `bool` | `true` | no |
| bucket_name | Name of bucket (existing or new) | `string` | n/a | yes |
| bucket_prefix | Prefix for the S3 bucket path (must end with '/') | `string` | `""` | no |
| access_grants_instance_arn | ARN of the S3 Access Grants instance | `string` | n/a | yes |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the S3 bucket |
| bucket_arn | ARN of the S3 bucket |
| location_arn | ARN of the Access Grants location |
| location_id | ID of the Access Grants location |
| iam_role_arn | ARN of the IAM role for this location |
| s3_prefix_arn | S3 prefix ARN for this location |
