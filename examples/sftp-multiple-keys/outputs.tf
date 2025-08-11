output "server_id" {
  description = "ID of the Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "Endpoint of the Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "user_details" {
  description = "Details of created users including their public keys"
  value       = module.sftp_users.user_details
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for file storage"
  value       = module.s3_bucket.s3_bucket_id
}