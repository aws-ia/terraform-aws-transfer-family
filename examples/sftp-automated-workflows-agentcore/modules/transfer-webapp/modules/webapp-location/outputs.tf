output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = local.bucket_name
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = local.bucket_arn
}

output "location_arn" {
  description = "ARN of the Access Grants location"
  value       = aws_s3control_access_grants_location.location.access_grants_location_arn
}

output "location_id" {
  description = "ID of the Access Grants location"
  value       = aws_s3control_access_grants_location.location.access_grants_location_id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for this location"
  value       = aws_iam_role.location.arn
}

output "s3_prefix_arn" {
  description = "S3 prefix ARN for this location"
  value       = local.s3_prefix_arn
}
