output "web_app_access_endpoint" {
  description = "The access endpoint URL for the Transfer web app"
  value       = module.transfer_web_app.web_app_access_endpoint
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
  value       = module.transfer_web_app.cloudtrail_arn
}

output "created_users" {
  description = "Map of created Identity Store users"
  value = {
    for key, user in var.users : key => {
      display_name = user.display_name
      user_name    = key
      email        = user.email
    }
  }
}

output "created_groups" {
  description = "Map of created Identity Store groups"
  value = {
    for key, group in var.groups : key => {
      group_name  = group.group_name
      description = group.description
    }
  }
}

output "access_grants_instance_arn" {
  description = "The ARN of the S3 Access Grants instance"
  value       = var.access_grants_instance_arn == null ? aws_s3control_access_grants_instance.instance[0].access_grants_instance_arn : null
}
