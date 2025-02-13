
# variable "aws_region" {
#   description = "AWS region"
#   type        = string
#   default     = "us-east-1"
# }

# variable "users_file" {
#   description = "Path to CSV file containing user configurations"
#   type        = string
#   default     = "users.csv"
# }

variable "transfer_server_base" {
  description = "Base configuration for Transfer Server"
  type = object({
    domain         = string
    protocols      = list(string)
    endpoint_type  = string
    server_name    = string
  })
  
  default = {
    domain         = "S3"
    protocols      = ["SFTP"]
    endpoint_type  = "PUBLIC"
    server_name    = "transfer-server"
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

# variable "identity_provider" {
#   description = "Identity provider configuration"
#   type = object({
#     type           = string
#     directory_id   = optional(string)
#     function_name  = optional(string)
#     url            = optional(string)
#     invocation_role = optional(string)
#   })
  
#   default = {
#     type = "SERVICE_MANAGED"
#   }

#   validation {
#     condition     = contains(["SERVICE_MANAGED", "AWS_DIRECTORY_SERVICE", "AWS_LAMBDA", "API_GATEWAY"], var.identity_provider.type)
#     error_message = "Identity provider type must be one of: SERVICE_MANAGED, AWS_DIRECTORY_SERVICE, AWS_LAMBDA, API_GATEWAY"
#   }
# }

# variable "custom_hostname" {
#   description = "Custom hostname configuration"
#   type = object({
#     enabled  = bool
#     hostname = optional(string)
#   })
  
#   default = {
#     enabled = false
#   }
# }

variable "iam_logging_role" {
  description = "(Optional) The ARN of the IAM role for Transfer Family logging. If not provided, logging will be disabled."
  type        = string
  default     = null
}

variable "security_policy_name" {
  description = "(Optional) Specifies the name of the security policy that is attached to the server. If not provided, the default security policy will be used."
  type        = string
  default     = null

  validation {
    condition     = contains([
      "TransferSecurityPolicy-2018-11",
      "TransferSecurityPolicy-2020-06",
      "TransferSecurityPolicy-2022-03",
      "TransferSecurityPolicy-2023-05",
      "TransferSecurityPolicy-2024-01",
      "TransferSecurityPolicy-FIPS-2020-06",
      "TransferSecurityPolicy-FIPS-2023-05",
      "TransferSecurityPolicy-FIPS-2024-01",
      "TransferSecurityPolicy-FIPS-2024-05",
      "TransferSecurityPolicy-PQ-SSH-Experimental-2023-04",
      "TransferSecurityPolicy-PQ-SSH-FIPS-Experimental-2023-04",
      "TransferSecurityPolicy-Restricted-2018-11",
      "TransferSecurityPolicy-Restricted-2020-06",
      "TransferSecurityPolicy-Restricted-2024-06"
    ], var.security_policy_name.type)
    error_message = "Security policy name must be one of the supported security policy names. visit https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html for more information."
  }
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}