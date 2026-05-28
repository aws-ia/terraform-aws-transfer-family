variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

# Feature flags for incremental demo stages.
# Defaults are `true` so a fresh `terraform apply` from the example root
# deploys the full end-to-end pipeline. The walkthrough/stageN.tfvars files
# override these flags to enable only a subset for the staged learning path.
variable "enable_identity_center" {
  type        = bool
  description = "Enable IAM Identity Center integration"
  default     = true
}

variable "enable_s3_access_grants" {
  type        = bool
  description = "Enable S3 Access Grants"
  default     = true
}

variable "enable_cognito" {
  type        = bool
  description = "Enable Cognito user pool for authentication"
  default     = true
}

variable "enable_custom_idp" {
  type        = bool
  description = "Enable custom identity provider solution"
  default     = true
}

variable "enable_transfer_server" {
  type        = bool
  description = "Enable Transfer Family server"
  default     = true
}

variable "enable_malware_protection" {
  type        = bool
  description = "Enable GuardDuty malware protection"
  default     = true
}

variable "enable_agentcore_agents" {
  type        = bool
  description = "Enable AgentCore agent runtimes (the AI agents themselves; created early so their build step runs alongside the foundation). The gateway wiring and orchestrator Lambda that actually invoke them are gated separately by enable_agentcore."
  default     = true
}

variable "enable_agentcore" {
  type        = bool
  description = "Enable the AgentCore orchestration layer (gateway + gateway targets + claims_reader Lambda + DynamoDB + claims_orchestrator). Requires enable_agentcore_agents = true since the orchestrator invokes agent runtimes created by that flag."
  default     = true

  validation {
    condition     = var.enable_agentcore == false || var.enable_agentcore_agents == true
    error_message = "enable_agentcore requires enable_agentcore_agents = true — the orchestrator can only run once the agent runtimes exist."
  }
}

variable "enable_webapp" {
  type        = bool
  description = "Enable web application for internal users"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default = {
    Environment = "Demo"
    Project     = "Transfer Family POC"
  }
}

variable "cognito_username" {
  description = "Username for the AnyCompany Auto Repair user"
  type        = string
  default     = "anycompany-repairs"
}

variable "cognito_user_email" {
  description = "Email address for the AnyCompany Auto Repair user"
  type        = string
  default     = "repairs@anycompany.example.com"
}

variable "cognito_domain_prefix" {
  description = "Domain prefix for Cognito hosted UI"
  type        = string
  default     = "anycompany-insurance"
}
