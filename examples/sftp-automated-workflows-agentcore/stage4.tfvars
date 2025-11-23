################################################################################
# Stage 4: Add Web Access for Internal Users
# Components: All stages - Complete solution
#
# This stage completes the solution with internal user access:
# - Transfer Family Web App for browser-based file access
# - S3 Access Grants integration for fine-grained permissions
# - Role-based access for Claims Admins and Claims Reviewers
# - Direct access to clean files after malware scanning
################################################################################

################################################################################
# All Components (Enable)
################################################################################

enable_identity_center    = true  # IAM Identity Center for internal user management
enable_s3_access_grants   = true  # S3 Access Grants for granular permissions
enable_cognito            = true  # Cognito User Pool for external authentication
enable_custom_idp         = true  # Custom Lambda IDP for Transfer Family
enable_transfer_server    = true  # SFTP server for file uploads
enable_malware_protection = true  # GuardDuty malware scanning and routing
enable_agentcore          = true  # AI claims processing with Bedrock
enable_webapp             = true  # Web app for internal user access

################################################################################
# Cognito Configuration
################################################################################

cognito_username      = "anycompany-repairs"              # External user username
cognito_user_email    = "repairs@anycompany.example.com"  # External user email
cognito_domain_prefix = "anycompany-insurance"            # Cognito hosted UI domain prefix

################################################################################
# Web App Configuration
################################################################################

uploads_bucket_name = "transfer-uploads"  # S3 bucket name for file uploads

################################################################################
# Resource Tags
################################################################################

tags = {
  Environment = "Dev"
  DeployedFrom   = "terraform-aws-transfer-family"
  ExampleName = "sftp-automated-workflows-agentcore"
}
