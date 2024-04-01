output "acm_arn" {
  description = "arn of the acm"
  value       = var.enable_waf == true ? aws_acm_certificate_validation.alb[0].certificate_arn : ""
}

resource "aws_acm_certificate" "alb" {
  count             = var.enable_waf == true ? 1 : 0
  domain_name       = local.dns_name
  validation_method = "DNS"
  depends_on = [
    aws_route53_record.ipa-app-caa
  ]
}


resource "aws_route53_record" "alb" {
  for_each = var.enable_waf ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
  provider        = aws.dns-control
}


resource "aws_acm_certificate_validation" "alb" {
  count                   = var.enable_waf == true ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.alb : record.fqdn]
  depends_on = [
    aws_acm_certificate.alb[0]
  ]
}

resource "aws_acmpca_certificate_authority_certificate" "indico" {
  count                     = var.network_allow_public == false ? 1 : 0
  certificate_authority_arn = aws_acmpca_certificate_authority.indico[0].arn

  certificate       = aws_acmpca_certificate.indico[0].certificate
  certificate_chain = aws_acmpca_certificate.indico[0].certificate_chain
}

resource "aws_acmpca_certificate" "indico" {
  count                       = var.network_allow_public == false ? 1 : 0
  certificate_authority_arn   = aws_acmpca_certificate_authority.indico[0].arn
  certificate_signing_request = aws_acmpca_certificate_authority.indico[0].certificate_signing_request
  signing_algorithm           = "SHA256WITHRSA"

  template_arn = "arn:${data.aws_partition.current.partition}:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 5
  }
}

data "aws_partition" "current" {}

resource "aws_acmpca_certificate_authority" "indico" {
  count = var.network_allow_public == false ? 1 : 0
  type  = "ROOT"
  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      common_name = local.dns_name
    }
  }
  usage_mode                      = "SHORT_LIVED_CERTIFICATE"
  permanent_deletion_time_in_days = 7
}
