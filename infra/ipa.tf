data "aws_route53_zone" "aws-zone" {
  name = lower("${var.aws_account}.indico.io")
}

output "ns" {
  value = data.aws_route53_zone.aws-zone.name_servers
}

data "external" "git_information" {
  program = ["sh", "${path.module}/get_sha.sh"]
}

output "git_sha" {
  value = data.external.git_information.result.sha
}

output "git_branch" {
  value = data.external.git_information.result.branch
}



output "smoketest_chart_version" {
  value = "${path.module}/validate_chart.sh terraform-smoketests 0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
}

output "local_registry_password" {
  value = htpasswd_password.hash.bcrypt
}

output "local_registry_username" {
  value = "local-user"
}

#output "zerossl" {
#  sensitive = true
#  value     = data.vault_kv_secret_v2.zerossl_data.data_json
#}
