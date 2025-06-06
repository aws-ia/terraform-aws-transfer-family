######################################
# Defaults and Locals
######################################

locals {
  dns_providers = {
    route53 = "route53"
    other   = "other"
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
  #checkov:skip=CKV_AWS_164: "Transfer server can intentionally be public facing for SFTP access
  identity_provider_type      = var.identity_provider
  domain                      = var.domain
  protocols                   = var.protocols
  endpoint_type               = var.endpoint_type
  security_policy_name        = var.security_policy_name
  structured_log_destinations = var.enable_logging ? ["${aws_cloudwatch_log_group.transfer[0].arn}:*"] : []
  logging_role                = var.logging_role

  dynamic "workflow_details" {
    for_each = var.workflow_details != null ? [1] : []
    content {
      dynamic "on_upload" {
        for_each = var.workflow_details.on_upload != null ? [var.workflow_details.on_upload] : []
        content {
          execution_role = on_upload.value.execution_role
          workflow_id    = on_upload.value.workflow_id
        }
      }

      dynamic "on_partial_upload" {
        for_each = var.workflow_details.on_partial_upload != null ? [var.workflow_details.on_partial_upload] : []
        content {
          execution_role = on_partial_upload.value.execution_role
          workflow_id    = on_partial_upload.value.workflow_id
        }
      }
    }
  }

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
  count        = (local.route53_enabled && local.is_valid_route53_domain) ? 1 : 0
  name         = var.route53_hosted_zone_name
  private_zone = false
}

resource "aws_transfer_tag" "with_custom_domain_name" {
  count        = local.custom_hostname_enabled ? 1 : 0
  resource_arn = aws_transfer_server.transfer_server.arn
  key          = "aws:transfer:customHostname" # This is a necessary tag to set a custom hostname with you transfer server endpoint. See https://docs.aws.amazon.com/transfer/latest/userguide/requirements-dns.html#tag-custom-hostname-cdk for full documentation.
  value        = var.custom_hostname
}

resource "aws_transfer_tag" "with_custom_domain_route53_zone_id" {
  count        = (local.route53_enabled && local.is_valid_route53_domain) ? 1 : 0
  resource_arn = aws_transfer_server.transfer_server.arn
  key          = "aws:transfer:route53HostedZoneId" # This is a necessary tag for Route53 to work with you transfer server endpoint. See https://docs.aws.amazon.com/transfer/latest/userguide/requirements-dns.html#tag-custom-hostname-cdk for full documentation.
  value        = "/hostedzone/${data.aws_route53_zone.selected[0].zone_id}"
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