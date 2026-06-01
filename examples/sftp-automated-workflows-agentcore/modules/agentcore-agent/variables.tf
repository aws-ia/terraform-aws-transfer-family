variable "name_prefix" {
  description = "Resource naming prefix (e.g. app_name-env_name)"
  type        = string
}

variable "agent_name" {
  description = "Short agent identifier used in resource names and S3 prefix (e.g. 'sanctions-agent')"
  type        = string
}

variable "agent_source_dir" {
  description = "Absolute path to the agent source code directory"
  type        = string
}

variable "entry_point" {
  description = "Entry point for code execution (e.g. ['app.py'])"
  type        = list(string)
  default     = ["app.py"]
}

variable "python_runtime" {
  description = "Python runtime version"
  type        = string
  default     = "PYTHON_3_13"
}

variable "python_runtime_version" {
  description = "Python runtime version"
  type        = string
  default     = "3.13"
}

variable "code_bucket_id" {
  description = "S3 bucket ID for agent code (created externally, shared across agents)"
  type        = string
}

variable "code_bucket_arn" {
  description = "S3 bucket ARN for agent code"
  type        = string
}

variable "data_bucket_arns" {
  description = "Optional list of S3 bucket ARNs the agent needs to read/list (GetObject + ListBucket). Leave empty if the agent only reads the code bucket."
  type        = list(string)
  default     = []
}

variable "enable_gateway" {
  description = "Whether to create the gateway invoke IAM policy (must be a static value, not derived from a resource)"
  type        = bool
  default     = false
}

variable "gateway_arn" {
  description = "AgentCore Gateway ARN for IAM permissions"
  type        = string
  default     = ""
}

variable "bedrock_model_id" {
  description = "Bedrock model ID the agent will invoke"
  type        = string
  default     = "global.anthropic.claude-sonnet-4-6"
}

variable "environment_variables" {
  description = "Environment variables to pass to the agent runtime"
  type        = map(string)
  default     = {}
}

variable "network_mode" {
  description = "Network mode for the agent runtime (PUBLIC or VPC)"
  type        = string
  default     = "PUBLIC"
}

variable "server_protocol" {
  description = "Server protocol (HTTP, MCP, A2A)"
  type        = string
  default     = "HTTP"
}

variable "tags" {
  type    = map(string)
  default = {}
}
