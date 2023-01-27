

module "shell-kube-credentials" {
  source       = "Invicton-Labs/shell-data/external"
  working_dir  = "/tmp"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
    az aro list-credentials --name os4 --resource-group os4-eastus --output json
  EOH
}


#  Now, we get back the output of the script
output "shell-kube-credentials-stdout" {
  value = module.shell-kube-credentials.stdout
}

#  Now, we get back the output of the script
output "shell-kube-credentials-stderr" {
  value = module.shell-kube-credentials.stderr
}



module "shell-kube-host" {
  depends_on = [
    module.shell-kube-credentials

  ]

  source       = "Invicton-Labs/shell-data/external"
  command_unix = <<EOH
    mkdir -p ${path.module}/tmpfiles
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" > /dev/null
    az aro show --name os4 --resource-group os4-eastus --query '{api:apiserverProfile.ip, ingress:ingressProfiles[0].ip, consoleUrl:consoleProfile.url, apiUrl:apiserverProfile.url}' --output json
  EOH
}


#  Now, we get back the output of the script
output "shell-kube-host-stdout" {
  value = module.shell-kube-host.stdout
}

#  Now, we get back the output of the script
output "shell-kube-host-stderr" {
  value = module.shell-kube-host.stderr
}

/*
module "shell-oc-login" {
  depends_on = [

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


#  Now, we get back the output of the script
output "shell-oc-login-stdout" {
  value = module.shell-oc-login.stdout
}
#  Now, we get back the output of the script
output "shell-oc-login-stderr" {
  value = module.shell-oc-login.stderr
}





data "local_file" "kubeconfig" {
  depends_on = [
    module.shell-oc-login
  ]
  filename = "/tmp/.openshift-config"
}
*/
