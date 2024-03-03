output "acm_arn" {
    description = "arn of the acm"
    value       = var.enable_waf == true ? aws_acm_certificate_validation.alb[0].certificate_arn : ""
}

output "wafv2_arn" {
    description = "arn of the wafv2 acl"
    value       = var.enable_waf == true ? aws_wafv2_web_acl.wafv2-acl[0].arn : ""
}
