variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "users_file" {
  description = "Path to CSV file containing user configurations"
  type        = string
  default     = "users.csv"
}

variable "transfer_server_base" {
  description = "Base configuration for Transfer Server"
  type = object({
    domain         = string
    protocols      = list(string)
    endpoint_type  = string
    environment    = string
  })
  
  default = {
    domain         = "S3"
    protocols      = ["SFTP"]
    endpoint_type  = "PUBLIC"
    environment    = "dev"
  }

  validation {
    condition     = contains(["S3", "EFS"], var.transfer_server_base.domain)
    error_message = "Domain must be either S3 or EFS"
  }

  validation {
    condition     = contains(["PUBLIC", "VPC", "VPC_ENDPOINT"], var.transfer_server_base.endpoint_type)
    error_message = "Endpoint type must be PUBLIC, VPC, or VPC_ENDPOINT"
  }
}

variable "identity_provider" {
  description = "Identity provider configuration"
  type = object({
    type           = string
    directory_id   = optional(string)
    function_name  = optional(string)
    url            = optional(string)
    invocation_role = optional(string)
  })
  
  default = {
    type = "SERVICE_MANAGED"
  }

  validation {
    condition     = contains(["SERVICE_MANAGED", "AWS_DIRECTORY_SERVICE", "AWS_LAMBDA", "API_GATEWAY"], var.identity_provider.type)
    error_message = "Identity provider type must be one of: SERVICE_MANAGED, AWS_DIRECTORY_SERVICE, AWS_LAMBDA, API_GATEWAY"
  }
}

variable "custom_hostname" {
  description = "Custom hostname configuration"
  type = object({
    enabled  = bool
    hostname = optional(string)
  })
  
  default = {
    enabled = false
  }
}