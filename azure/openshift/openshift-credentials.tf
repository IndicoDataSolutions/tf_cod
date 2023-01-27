

module "shell-kube-credentials" {
  depends_on = [
    module.cluster
  ]
  source       = "Invicton-Labs/shell-data/external"
  working_dir  = "/tmp"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
    az aro list-credentials --name ${var.label} --resource-group ${var.resource_group_name} --output json
  EOH
}

module "shell-kube-host" {
  depends_on = [
    module.shell-kube-credentials,
    module.cluster
  ]

  source       = "Invicton-Labs/shell-data/external"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
    az aro show --name ${var.label} --resource-group ${var.resource_group_name} --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json
  EOH
}

module "shell-debug-host" {
  depends_on = [
    module.shell-kube-credentials,
    module.cluster
  ]

  source       = "Invicton-Labs/shell-data/external"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID"
    az aro show --name ${var.label} --resource-group ${var.resource_group_name} --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json
   EOH
}


module "shell-oc-login" {
  depends_on = [
    module.cluster,
    module.shell-kube-credentials,
    module.shell-kube-host
  ]

  fail_on_nonzero_exit_code = true

  source = "Invicton-Labs/shell-data/external"
  environment = {
    KUBECONFIG = "/tmp/.openshift-config"
  }

  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    oc login https://${jsondecode(module.shell-kube-host.stdout)["api"]}:6443/ --insecure-skip-tls-verify=true --username ${jsondecode(module.shell-kube-credentials.stdout)["kubeadminUsername"]} --password ${jsondecode(module.shell-kube-credentials.stdout)["kubeadminPassword"]} > /dev/null
  EOH
}

data "local_file" "kubeconfig" {
  depends_on = [
    module.shell-oc-login
  ]
  filename = "/tmp/.openshift-config"
}
