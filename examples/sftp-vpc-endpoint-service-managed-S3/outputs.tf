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

output "user_details" {
  description = "Map of users with their details including secret names and ARNs"
  value = module.sftp_users.user_details
}