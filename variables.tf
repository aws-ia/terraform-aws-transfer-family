variable "server_name" {
  description = "The name of the Transfer Family server"
  type        = string
  default     = "transfer-server"
}

variable "domain" {
  description = "The domain of the storage system that is used for file transfers"
  type        = string
  default     = "S3"

  validation {
    condition     = contains(["S3"], var.domain)
    error_message = "Domain must be S3"
  }
}

variable "protocols" {
  description = "Specifies the file transfer protocol or protocols over which your file transfer protocol client can connect to your server's endpoint"
  type        = list(string)
  default     = ["SFTP"]

  validation {
    condition = alltrue([
      for protocol in var.protocols : contains(["SFTP"], protocol)
    ])
    error_message = "Valid protocols are: SFTP."
  }

  validation {
    condition     = length(var.protocols) > 0
    error_message = "At least one protocol must be specified."
  }
}

variable "endpoint_type" {
  description = "The type of endpoint that you want your transfer server to use"
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.endpoint_type)
    error_message = "Endpoint type must be one of: PUBLIC or VPC."
  }
}

variable "identity_provider" {
  description = "Identity provider configuration"
  type        = string
  default     = "SERVICE_MANAGED"

  validation {
    condition     = contains(["SERVICE_MANAGED"], var.identity_provider)
    error_message = "Identity provider type must be: SERVICE_MANAGED"
  }
}

variable "security_policy_name" {
  description = "Specifies the name of the security policy that is attached to the server. If not provided, the default security policy will be used."
  type        = string
  default     = "TransferSecurityPolicy-2024-01"

  validation {
    condition = contains([
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
    ], var.security_policy_name)
    error_message = "Security policy name must be one of the supported security policy names. visit https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html for more information."
  }
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "enable_logging" {
  description = "Enable CloudWatch logging for the transfer server"
  type        = bool
  default     = false
}

variable "dns_provider" {
  type        = string
  description = "The DNS provider for the custom hostname. Use 'none' for no custom hostname"
  default     = null
  validation {
    condition     = var.dns_provider == null ? true : contains(["route53", "other"], var.dns_provider)
    error_message = "The dns_provider value must be either null, 'route53', or 'other'."
  }
}

variable "custom_hostname" {
  type        = string
  description = "The custom hostname for the Transfer Family server"
  default     = null
}

variable "route53_hosted_zone_name" {
  description = "The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.')"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Number of days to retain logs for"
  type        = number
  default     = 30
}

variable "log_group_kms_key_id" {
  description = "encryption key for cloudwatch log group"
  type        = string
  default     = null
}

variable "logging_role" {
  description = "IAM role ARN that the Transfer Server assumes to write logs to CloudWatch Logs"
  type        = string
  default     = null
}

variable "endpoint_details" {
  description = "VPC endpoint configuration block for the Transfer Server"
  type = object({
    address_allocation_ids = optional(list(string))
    security_group_ids     = list(string)
    subnet_ids             = list(string)
    vpc_id                 = string
  })
  default = null

  validation {
    condition     = var.endpoint_details == null || try(var.endpoint_details.address_allocation_ids == null, true) || try(length(var.endpoint_details.address_allocation_ids) == length(var.endpoint_details.subnet_ids), true)
    error_message = "If address_allocation_ids is provided (INTERNET_FACING access), it must have the same length as subnet_ids."
  }

  validation {
    condition     = var.endpoint_details == null || try(length(var.endpoint_details.security_group_ids) > 0, false)
    error_message = "At least one security group ID must be provided in security_group_ids."
  }

  validation {
    condition     = var.endpoint_details == null || try(length(var.endpoint_details.subnet_ids) > 0, false)
    error_message = "At least one subnet ID must be provided in subnet_ids."
  }
}

variable "workflow_details" {
  description = "Workflow details to attach to the transfer server"
  type = object({
    on_upload = optional(object({
      execution_role = string
      workflow_id    = string
    }))
    on_partial_upload = optional(object({
      execution_role = string
      workflow_id    = string
    }))
  })
  default = null
}