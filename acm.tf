output "acm_arn" {
  description = "arn of the acm"
  value       = var.acm_arn == "" ? aws_acm_certificate_validation.alb[0].certificate_arn : var.acm_arn
}

resource "aws_acm_certificate" "alb" {
  count             = var.acm_arn == "" ? 1 : 0
  domain_name       = local.dns_name
  validation_method = "DNS"
  depends_on = [
    aws_route53_record.ipa-app-caa
  ]
}

resource "aws_acm_certificate_validation" "alb" {
  count                   = var.acm_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.alb : record.fqdn]
  depends_on = [
    aws_acm_certificate.alb[0]
  ]
}
