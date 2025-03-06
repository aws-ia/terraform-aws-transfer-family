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
}

######################################
# Basic Checks
######################################

check "route53_configuration" {
  assert {
    condition     = !(var.dns_provider == local.dns_providers.route53 && !local.route53_enabled)
    error_message = "When dns_provider is 'route53', both custom_hostname and route53_hosted_zone_name must be provided"
  }
}

check "custom_hostname_configuration" {
  assert {
    condition     = var.dns_provider == null || var.custom_hostname != null
    error_message = "When dns_provider is set, custom_hostname must be provided"
  }
}

check "dns_provider_configuration" {
  assert {
    condition     = var.dns_provider == null ? (var.custom_hostname == null && var.route53_hosted_zone_name == null) : true
    error_message = "When dns_provider is null, custom_hostname and route53_hosted_zone_name must also be null"
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
  count = local.route53_enabled ? 1 : 0
  name  = var.route53_hosted_zone_name
  private_zone = false

  lifecycle {
    precondition {
      condition = endswith(var.custom_hostname, replace(var.route53_hosted_zone_name, "/[.]$/", ""))
      error_message = "The custom hostname '${var.custom_hostname}' must be a subdomain of the hosted zone '${var.route53_hosted_zone_name}'"
    }
  }
}

resource "aws_transfer_tag" "with_custom_domain_name" {
  count        = local.custom_hostname_enabled ? 1 : 0
  resource_arn = aws_transfer_server.transfer_server.arn
  key          = "aws:transfer:customHostname"
  value        = var.custom_hostname
}

resource "aws_transfer_tag" "with_custom_domain_route53_zone_id" {
  count         = local.route53_enabled ? 1 : 0
  resource_arn  = aws_transfer_server.transfer_server.arn
  key           = "aws:transfer:route53HostedZoneId"
  value         = "/hostedzone/${data.aws_route53_zone.selected[0].zone_id}"
}

# Route 53 record
resource "aws_route53_record" "sftp" {
  count   = local.route53_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.custom_hostname
  type    = "CNAME"
  ttl     = "300"
  records = [aws_transfer_server.transfer_server.endpoint]
}