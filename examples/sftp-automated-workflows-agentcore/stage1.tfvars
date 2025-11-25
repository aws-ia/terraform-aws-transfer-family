################################################################################
# Stage 1: Transfer Server with External Users
# Components: Stage 0 + Transfer Family Server + Custom IDP
#
# This stage adds SFTP file upload capability:
# - Transfer Family SFTP server for secure file uploads
# - Custom Lambda IDP integrating Cognito authentication
# - S3 bucket for uploaded files
################################################################################

################################################################################
# Stage 0-1 Components (Enable)
################################################################################

enable_identity_center  = true  # IAM Identity Center for internal user management
enable_s3_access_grants = true  # S3 Access Grants for granular permissions
enable_cognito          = true  # Cognito User Pool for external authentication
enable_agentcore_ecr    = true  # ECR repos and Docker builds for AgentCore (from Stage 0)
enable_custom_idp       = true  # Custom Lambda IDP for Transfer Family
enable_transfer_server  = true  # SFTP server for file uploads

################################################################################
# Future Stages (Disabled)
################################################################################

enable_malware_protection = false  # Stage 2: GuardDuty malware scanning
enable_agentcore          = false  # Stage 3: AI claims processing (agent deployment)
enable_webapp             = false  # Stage 4: Web app for internal users

################################################################################
# Cognito Configuration
################################################################################

cognito_username      = "anycompany-repairs"                  # External user username
cognito_user_email    = "repairs@anycompany-repairs.com"      # External user email
cognito_domain_prefix = "anycompany-insurance"                # Cognito hosted UI domain prefix

################################################################################
# Resource Tags
################################################################################

tags = {
  Environment = "Dev"
  DeployedFrom   = "terraform-aws-transfer-family"
  ExampleName = "sftp-automated-workflows-agentcore"
}
