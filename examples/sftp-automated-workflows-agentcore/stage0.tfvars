################################################################################
# Stage 0: Identity Foundation + AgentCore ECR
# Components: IAM Identity Center, S3 Access Grants, Cognito, ECR Repos
#
# This stage establishes the identity and authentication foundation:
# - IAM Identity Center for internal users (claims team)
# - S3 Access Grants for fine-grained file access control
# - Cognito User Pool for external users (repair shops)
# - ECR repositories and Docker images for AgentCore agents
################################################################################

################################################################################
# Stage 0 Components (Enable)
################################################################################

enable_identity_center  = true  # IAM Identity Center for internal user management
enable_s3_access_grants = true  # S3 Access Grants for granular permissions
enable_cognito          = true  # Cognito User Pool for external authentication
enable_agentcore_ecr    = true  # ECR repos and Docker builds for AgentCore

################################################################################
# Future Stages (Disabled)
################################################################################

enable_custom_idp         = true   # Stage 1: Custom IDP for Transfer Family
enable_transfer_server    = false  # Stage 1: SFTP server for file uploads
enable_malware_protection = false  # Stage 2: GuardDuty malware scanning
enable_agentcore          = false  # Stage 3: AI claims processing (agent deployment)
enable_webapp             = false  # Stage 4: Web app for internal users

################################################################################
# Cognito Configuration
################################################################################

cognito_username      = "anycompany-repairs"              # External user username
cognito_user_email    = "repairs@anycompany.example.com"  # External user email
cognito_domain_prefix = "anycompany-insurance"            # Cognito hosted UI domain prefix

################################################################################
# Resource Tags
################################################################################

tags = {
  Environment = "Dev"
  DeployedFrom   = "terraform-aws-transfer-family"
  ExampleName = "sftp-automated-workflows-agentcore"
}
