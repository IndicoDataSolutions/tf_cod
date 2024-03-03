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

output "harbor-api-token" {
  sensitive = true
  value     = var.argo_enabled == true ? jsondecode(data.vault_kv_secret_v2.harbor-api-token[0].data_json)["bearer_token"] : ""
}

output "smoketest_chart_version" {
  value = "${path.module}/validate_chart.sh terraform-smoketests 0.1.0-${data.external.git_information.result.branch}-${substr(data.external.git_information.result.sha, 0, 8)}"
}

resource "random_password" "password" {
  length = 12
}

resource "random_password" "salt" {
  length = 8
}

resource "htpasswd_password" "hash" {
  password = random_password.password.result
  salt     = random_password.salt.result
}

output "local_registry_password" {
  value = htpasswd_password.hash.bcrypt
}

output "local_registry_username" {
  value = "local-user"
}

output "zerossl" {
  sensitive = true
  value     = data.vault_kv_secret_v2.zerossl_data.data_json
}