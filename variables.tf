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
    error_message = "Domain must be either S3"
  }
}

variable "protocols" {
  description = "Specifies the file transfer protocol or protocols over which your file transfer protocol client can connect to your server's endpoint"
  type        = list(string)
  default     = ["SFTP"]
}

variable "endpoint_type" {
  description = "The type of endpoint that you want your transfer server to use"
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC"], var.endpoint_type)
    error_message = "Endpoint type must be PUBLIC"
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
  default     = "TransferSecurityPolicy-2018-11"

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