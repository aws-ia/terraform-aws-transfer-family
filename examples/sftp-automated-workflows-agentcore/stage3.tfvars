################################################################################
# Stage 3: Add AI Claims Processing
# Components: Stage 0 + Stage 1 + Stage 2 + Agentcore with Bedrock
#
# This stage adds the AI orchestration layer that drives the pre-built
# AgentCore agents (created in stage 0):
# - MCP gateway + claims_reader Lambda (tool backend for 3 agents)
# - Claims orchestrator Lambda (S3 event → agent pipeline)
# - DynamoDB table for claim records
# - In-place update: 3 agents gain invoke-gateway IAM + AGENTCORE_GATEWAY_URL
################################################################################

################################################################################
# Stage 0-3 Components (Enable)
################################################################################

enable_identity_center    = true # IAM Identity Center for internal user management
enable_s3_access_grants   = true # S3 Access Grants for granular permissions
enable_cognito            = true # Cognito User Pool for external authentication
enable_agentcore_agents   = true # AgentCore agent runtimes (from stage 0)
enable_custom_idp         = true # Custom Lambda IDP for Transfer Family
enable_transfer_server    = true # SFTP server for file uploads
enable_malware_protection = true # GuardDuty malware scanning and routing
enable_agentcore          = true # AI claims orchestration (gateway + orchestrator; wires agents in)

################################################################################
# Future Stages (Disabled)
################################################################################

enable_webapp = false # Stage 4: Web app for internal users

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
