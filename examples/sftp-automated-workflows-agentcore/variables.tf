variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

# Feature flags for incremental demo stages
variable "enable_identity_center" {
  type        = bool
  description = "Enable IAM Identity Center integration"
  default     = false
}

variable "enable_s3_access_grants" {
  type        = bool
  description = "Enable S3 Access Grants"
  default     = false
}

variable "enable_cognito" {
  type        = bool
  description = "Enable Cognito user pool for authentication"
  default     = false
}

variable "enable_custom_idp" {
  type        = bool
  description = "Enable custom identity provider solution"
  default     = false
}

variable "enable_transfer_server" {
  type        = bool
  description = "Enable Transfer Family server"
  default     = false
}

variable "enable_malware_protection" {
  type        = bool
  description = "Enable GuardDuty malware protection"
  default     = false
}

variable "enable_agentcore" {
  type        = bool
  description = "Enable AI claims processing with Bedrock"
  default     = false
}

variable "enable_webapp" {
  type        = bool
  description = "Enable web application for internal users"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default = {
    Environment = "Demo"
    Project     = "Transfer Family POC"
  }
}
