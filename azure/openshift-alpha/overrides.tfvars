name          = "axa"
label         = "axa"
region        = "eastus"
account       = "indico-dev"
domain_suffix = "indico.io"

# lower("${var.account}.${var.domain_suffix}")     

# url will be ${label}.${region}.${account}.${domain_suffix}
# e.g: dev.eastus.indico.axa.com

# ipa configuration
ipa_smoketest_enabled = false
ipa_enabled           = false
ipa_repo              = "https://harbor.devops.indico.io/chartrepo/indico-charts"
ipa_version           = "0.17.1-IPA-6.1.0.rc-314c337c"
ipa_pre_reqs_version  = "0.9.3-IPA-6.1.0.rc-314c337c"
ipa_crds_version      = "0.4.0-IPA-6.1.0.rc-314c337c"
monitoring_version    = "0.4.1-IPA-6.1.0.rc-314c337c"

storage_account_name = "axa"

vault_mount_path = "axa-openshift"
vault_username   = "axa-openshift"
vault_password   = "[issued from pre-requisites above]"
argo_enabled     = false
