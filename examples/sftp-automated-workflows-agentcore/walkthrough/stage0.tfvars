################################################################################
# Stage 0: Identity Foundation + Custom IDP + AgentCore Agent Runtimes
# Components: IAM Identity Center, S3 Access Grants, Cognito, Transfer Custom
#             IDP, AgentCore Agents
#
# This stage establishes the identity and authentication foundation plus the
# AgentCore agent runtimes themselves:
# - IAM Identity Center for internal users (claims team)
# - S3 Access Grants for fine-grained file access control
# - Cognito User Pool for external users (repair shops)
# - Transfer Custom IDP Lambda (built with CodeBuild; used by stage 1)
# - 4 AgentCore agent runtimes (document extraction, damage assessment,
#   fraud detection, classification) created with minimal config. Data-bucket
#   wiring is attached in stage 2, gateway wiring in stage 3.
################################################################################

################################################################################
# Stage 0 Components (Enable)
################################################################################

enable_identity_center  = true # IAM Identity Center for internal user management
enable_cognito          = true # Cognito User Pool for external authentication
enable_agentcore_agents = true # AgentCore agent runtimes (builds + registers 4 agents)
enable_agentcore_observability    = true # CloudWatch Transaction Search + agent log/trace delivery
enable_custom_idp       = true # Custom IDP for Transfer Family

################################################################################
# Future Stages (Disabled)
################################################################################

enable_transfer_server    = false # Stage 1: SFTP server for file uploads
enable_malware_protection = false # Stage 2: GuardDuty malware scanning
enable_agentcore          = false # Stage 3: AI claims orchestration (gateway + orchestrator)
enable_webapp             = false # Stage 4: Web app for internal users

################################################################################
# Cognito Configuration
################################################################################

cognito_username      = "anycompany-repairs"             # External user username
cognito_user_email    = "repairs@anycompany.example.com" # External user email
cognito_domain_prefix = "anycompany-insurance"           # Cognito hosted UI domain prefix

################################################################################
# Resource Tags
################################################################################

tags = {
  Environment  = "Dev"
  DeployedFrom = "terraform-aws-transfer-family"
  ExampleName  = "sftp-automated-workflows-agentcore"
}
