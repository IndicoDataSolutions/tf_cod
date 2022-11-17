module "acm" {
  count    = var.use_acm == true ? 0 : 1
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = local.dns_name
  zone_id      = data.aws_route53_zone.primary.zone_id


  wait_for_validation = true

  tags = {
    Name = local.dns_name
  }
}

output "acm_arn" {
    description = "arn of the acm"
    value       = var.use_acm == true ? module.acm[0].acm_certificate_arn : ""
}