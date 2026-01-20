output "web_app_endpoint" {
  description = "The web app endpoint URL for access and CORS configuration"
  value       = module.transfer_web_app.web_app_endpoint
}

output "web_app_id" {
  description = "The ID of the Transfer web app"
  value       = module.transfer_web_app.web_app_id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for file storage"
  value       = module.s3_bucket.s3_bucket_arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail for audit logging"
  value       = aws_cloudtrail.web_app_audit.arn
}

output "created_users" {
  description = "Map of created Identity Store users"
  value = var.create_test_users_and_groups ? {
    for key, user in var.test_users : key => {
      display_name = user.display_name
      user_name    = key
      email        = user.email
    }
  } : {}
}

output "created_groups" {
  description = "Map of created Identity Store groups"
  value = var.create_test_users_and_groups ? {
    for key, group in var.test_groups : key => {
      group_name  = group.group_name
      description = group.description
    }
  } : {}
}

output "access_grants_instance_arn" {
  description = "The ARN of the S3 Access Grants instance"
  value       = module.transfer_web_app.access_grants_instance_arn
}
