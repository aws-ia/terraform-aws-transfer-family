output "server_id" {
  description = "The ID of the created Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the created Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "sftp_bucket_name" {
  description = "The name of the S3 bucket used for SFTP storage"
  value       = module.s3_bucket.s3_bucket_id
}

output "document_storage_bucket_name" {
  description = "The name of the S3 bucket used for document storage"
  value       = module.document_storage_bucket.s3_bucket_id
}

output "document_storage_bucket_arn" {
  description = "The ARN of the S3 bucket used for document storage"
  value       = module.document_storage_bucket.s3_bucket_arn
}

output "user_details" {
  description = "Map of users with their details including secret names and ARNs"
  value       = module.sftp_users.user_details
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.arn
}

output "kms_key_alias" {
  description = "The alias of the KMS key used for encryption"
  value       = aws_kms_alias.transfer_family_key_alias.name
}