######################################
# Defaults and Locals
######################################

locals {
  dns_providers = {
    route53 = "route53"
    other = "other"
  }

  # Validate custom hostname configuration
  custom_hostname_enabled = (
    var.dns_provider != null && 
    var.custom_hostname != null
  )

  # Validate Route53 configuration
  route53_enabled = (
    var.dns_provider == local.dns_providers.route53 && 
    var.custom_hostname != null && 
    var.route53_hosted_zone_name != null
  )

  # Validate if the custom hostname is a subdomain of the Route53 hosted zone
  is_valid_route53_domain = try(
    endswith(var.custom_hostname, replace(var.route53_hosted_zone_name, "/[.]$/", "")) && 
    var.custom_hostname != var.route53_hosted_zone_name,
    false
  )
}

######################################
# Basic Checks
######################################

check "route53_configuration" {
  assert {
    condition     = !(var.dns_provider == local.dns_providers.route53 && !local.route53_enabled)
    error_message = <<-EOT
      When dns_provider is 'route53', both custom_hostname and route53_hosted_zone_name must be provided.
      The transfer server will be created without a custom hostname for the endpoint.
      EOT
  }

  assert {
    condition     = !(var.dns_provider == local.dns_providers.route53 && !local.is_valid_route53_domain)
    error_message = <<-EOT
      When using Route53, the custom hostname must be a subdomain of the hosted zone
      The transfer server will be created without a custom hostname for the endpoint.
    EOT
  }
}

check "custom_hostname_configuration" {
  assert {
    condition     = var.dns_provider != local.dns_providers.other || var.custom_hostname != null
    error_message = <<-EOT
      When dns_provider is 'other', custom_hostname must be provided.
      The transfer server will be created without a custom hostname for the endpoint.
      EOT
  }
}

check "dns_provider_configuration" {
  assert {
    condition     = var.dns_provider == null ? (var.custom_hostname == null && var.route53_hosted_zone_name == null) : true
    error_message = <<-EOT
      When dns_provider is null, custom_hostname and route53_hosted_zone_name must also be null.
      The transfer server will be created without a custom hostname for the endpoint.
      EOT
  }
}

######################################
# Transfer Module
######################################

resource "aws_transfer_server" "transfer_server" {
#checkov:skip=CKV_AWS_164: "Transfer server can intentionally be public facing for SFTP access"
  identity_provider_type    = var.identity_provider
  domain                    = var.domain
  protocols                 = var.protocols
  endpoint_type             = var.endpoint_type
  security_policy_name      = var.security_policy_name
  logging_role              = var.enable_logging ? aws_iam_role.logging[0].arn : null

  tags = merge(
    var.tags,
    {
      Name = var.server_name
    }
  )
}

###########################################
# Custom hostname for transfer server
###########################################

data "aws_route53_zone" "selected" {
  count = (local.route53_enabled && local.is_valid_route53_domain) ? 1 : 0
  name  = var.route53_hosted_zone_name
  private_zone = false
}

resource "aws_transfer_tag" "with_custom_domain_name" {
  count        = local.custom_hostname_enabled ? 1 : 0
  resource_arn = aws_transfer_server.transfer_server.arn
  key          = "aws:transfer:customHostname"
  value        = var.custom_hostname
}

resource "aws_transfer_tag" "with_custom_domain_route53_zone_id" {
  count         = (local.route53_enabled && local.is_valid_route53_domain) ? 1 : 0
  resource_arn  = aws_transfer_server.transfer_server.arn
  key           = "aws:transfer:route53HostedZoneId"
  value         = "/hostedzone/${data.aws_route53_zone.selected[0].zone_id}"
}

# Route 53 record
resource "aws_route53_record" "sftp" {
  count   = (local.route53_enabled && local.is_valid_route53_domain) ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.custom_hostname
  type    = "CNAME"
  ttl     = "300"
  records = [aws_transfer_server.transfer_server.endpoint]
}

###########################################
# Cloudwatch log group 
###########################################

# Cloudwatch log group
resource "aws_cloudwatch_log_group" "transfer" {
# checkov:skip=CKV_AWS_338: Default retention period set to 30 days. Change value per your own requirements 
  count             = var.enable_logging ? 1 : 0
  name              = "/aws/transfer/${var.server_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
  kms_key_id        = var.log_group_kms_key_id
}

# IAM Role with managed policy
resource "aws_iam_role" "logging" {
  count = var.enable_logging ? 1 : 0
  name  = "${var.server_name}-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy
resource "aws_iam_role_policy_attachment" "logging" {
  count      = var.enable_logging ? 1 : 0
  role       = aws_iam_role.logging[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
}