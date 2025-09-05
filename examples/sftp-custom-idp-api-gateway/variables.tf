variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "test_user_1" {
  description = "Configuration for admin test user"
  type = object({
    username = string
    email    = string
    password = string
  })
  default = {
    username = "admin"
    email    = "admin@example.com"
    password = "AdminPass123!"
  }
  sensitive = true
}

variable "test_user_2" {
  description = "Configuration for regular test user"
  type = object({
    username = string
    email    = string
    password = string
  })
  default = {
    username = "user"
    email    = "user@example.com"
    password = "UserPass123!"
  }
  sensitive = true
}

variable "ldap_config" {
  description = "LDAP configuration for fallback authentication"
  type = object({
    server                 = string
    port                  = number
    base_dn               = string
    bind_dn               = string
    bind_password_secret  = string
    disabled              = bool
  })
  default = {
    server                = "ldap.example.com"
    port                  = 389
    base_dn               = "dc=example,dc=com"
    bind_dn               = "cn=service,dc=example,dc=com"
    bind_password_secret  = "ldap-bind-password"
    disabled              = true  # Disabled by default since LDAP server doesn't exist
  }
  sensitive = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "test"
    Project     = "transfer-family-api-gateway-example"
    ManagedBy   = "terraform"
  }
}