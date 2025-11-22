output "web_app_endpoint" {
  description = "URL endpoint for the Transfer Family Web App"
  value       = module.transfer_webapp.web_app_endpoint
}

output "web_app_id" {
  description = "ID of the Transfer Family Web App"
  value       = module.transfer_webapp.web_app_id
}

output "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance"
  value       = module.transfer_webapp.access_grants_instance_arn
}

# Uploads Location Outputs
output "uploads_bucket_name" {
  description = "Name of the uploads S3 bucket"
  value       = module.uploads_location.bucket_name
}

output "uploads_location_id" {
  description = "ID of the uploads Access Grants location"
  value       = module.uploads_location.location_id
}

# Shared Location Outputs
output "shared_bucket_name" {
  description = "Name of the shared documents S3 bucket"
  value       = module.shared_location.bucket_name
}

output "shared_location_id" {
  description = "ID of the shared documents Access Grants location"
  value       = module.shared_location.location_id
}

# User and Group Assignment Outputs
output "user_assignments" {
  description = "Details of user assignments to the web app"
  value       = module.webapp_users_and_groups.user_assignments
}

output "group_assignments" {
  description = "Details of group assignments to the web app"
  value       = module.webapp_users_and_groups.group_assignments
}

output "user_access_grants" {
  description = "Details of access grants created for users"
  value       = module.webapp_users_and_groups.user_access_grants
}

output "group_access_grants" {
  description = "Details of access grants created for groups"
  value       = module.webapp_users_and_groups.group_access_grants
}

# Helpful S3 Paths
output "user1_folder_path" {
  description = "S3 path for user1's personal folder in uploads bucket"
  value       = "s3://${module.uploads_location.bucket_name}/user/${var.user1_username}/"
}

output "shared_documents_path" {
  description = "S3 path for the shared documents"
  value       = "s3://${module.shared_location.bucket_name}/documents/"
}
