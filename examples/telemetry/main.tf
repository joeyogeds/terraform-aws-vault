# Make a certificate.
resource "aws_acm_certificate" "default" {
  domain_name = "telemetry.meinit.nl"
  # After a deployment, this value (`domain_name`) can't be changed because the certificate is bound to the load balancer listener.
  validation_method = "DNS"
  tags = {
    owner = "Robert de Bock"
  }
}

# Lookup DNS zone.
data "aws_route53_zone" "default" {
  name = "meinit.nl"
}

# Add validation details to the DNS zone.
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.default.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.default.zone_id
}

# Call the module.
module "vault" {
  source                    = "../../"
  vault_aws_certificate_arn = aws_acm_certificate.default.arn
  vault_enable_telemetry    = true
  vault_keyfile_path        = "id_rsa.pub"
  vault_name                = "tlmtr"
  vault_tags = {
    owner = "Robert de Bock"
  }
}

# Add a loadbalancer record to DNS zone.
resource "aws_route53_record" "default" {
  name    = "telemetry"
  records = [module.vault.aws_lb_dns_name]
  ttl     = 300
  type    = "CNAME"
  zone_id = data.aws_route53_zone.default.id
}