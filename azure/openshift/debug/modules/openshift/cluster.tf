
variable "label" {}
variable "resource_group_name" {}

resource "null_resource" "get-cluster-data" {

  triggers = {
    always_run = "${timestamp()}"
  }


  # generates files in /tmp
  provisioner "local-exec" {
    command     = "${path.module}/get_cluster_data.sh ${var.label} ${var.resource_group_name}"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "get-cluster-token-debug-show" {
  triggers = {
    always_run = "${timestamp()}"
  }


  # generates files in /tmp
  provisioner "local-exec" {
    command     = "cat ${path.module}/get_token.sh "
    interpreter = ["/bin/bash", "-c"]
  }
}

data "local_file" "sa_token" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/sa_token"
}

data "local_file" "sa_cert" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/sa_cert"
}


data "local_file" "sa_username" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/sa_username"
}

data "local_file" "user_token" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/user_token"
}

data "local_file" "username" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/username"
}

data "local_file" "password" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/password"
}

data "local_file" "api_ip" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/api_ip"
}

data "local_file" "api_url" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/api_url"
}

data "local_file" "console_ip" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/console_ip"
}

data "local_file" "console_url" {
  depends_on = [
    null_resource.get-cluster-data
  ]
  filename = "/tmp/console_url"
}


# Stubbed outputs (not used)
output "kubelet_identity" {
  value = {
    object_id = "ERROR:OPENSHIFT-NOT-APPLICABLE"
    client_id = "ERROR:OPENSHIFT-NOT-APPLICABLE"
  }
}

output "oidc_issuer_url" {
  value = "ERROR:OPENSHIFT-NOT-APPLICABLE"
}

output "id" {
  value = "ERROR:OPENSHIFT-NOT-APPLICABLE"
}

output "kubernetes_host" {
  value = trimspace(data.local_file.api_ip.content)
}

output "kubernetes_insecure" {
  value = false
}

output "kubernetes_url" {
  value = trimspace(data.local_file.api_url.content)
}

output "kubernetes_token" {
  value = trimspace(data.local_file.user_token.content)
}

output "kubernetes_sa_username" {
  value = trimspace(data.local_file.sa_username.content)
}

output "kubernetes_sa_token" {
  value = trimspace(data.local_file.sa_token.content)
}

output "kubernetes_sa_cert" {
  value = trimspace(data.local_file.sa_cert.content)
}

#  Now, we get back the output of the script
output "kubernetes_username" {
  value = trimspace(data.local_file.username.content)
}

output "kubernetes_password" {
  value = trimspace(data.local_file.password.content)
}

output "api_server_ip" {
  value = trimspace(data.local_file.api_ip.content)
}

output "console_ingress_ip" {
  value = trimspace(data.local_file.console_url.content)
}



