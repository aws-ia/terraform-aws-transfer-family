output "server_id" {
  description = "The ID of the Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "okta_user_id" {
  description = "Okta user ID"
  value       = data.okta_user.sftp_user.id
}

output "okta_user_email" {
  description = "Email address of the Okta user"
  value       = data.okta_user.sftp_user.email
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = module.s3_bucket.s3_bucket_id
}

output "connection_instructions" {
  description = "Instructions for connecting to the SFTP server"
  value       = <<-EOT
    Connect via SFTP using your existing Okta credentials:
    
    sftp ${data.okta_user.sftp_user.email}@${module.transfer_server.server_endpoint}
    
    Use your Okta password when prompted.
  EOT
}
