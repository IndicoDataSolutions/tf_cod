do_install_ipa_crds = true
do_deploy_ipa       = true
argo_enabled        = true

is_openshift          = true
include_external_dns  = false
use_workload_identity = false

ipa_namespace      = "indico"
ipa_crds_namespace = "indico"


svp_client_id     = "na"
svp_client_secret = "na"

# fill out this file with desired values and reference it 

region                  = "eastus"
vnet_cidr               = "192.168.0.0/20"
subnet_cidrs            = ["192.168.0.0/22"]
worker_subnet_cidrs     = ["192.168.4.0/26"]
storage_account_name    = "indicodatatest"
cluster_manager_vm_size = "Standard_F2s"

#
#  az vm image list --all --offer aro4 --publisher azureopenshift -o table
#
#image:
# offer: aro4
# publisher: azureopenshift
# resourceID: ""
# sku: aro_410
# version: 410.84.20220125

openshift_machine_sets = {
  gpuworkers = {
    node_count = 0
    pool_name  = "gpu"
    vm_size    = "Standard_NC4as_T4_v3"
    node_os    = "Linux"
    zones      = ["0"]
    taints     = ["nvidia.com/gpu=true:NoSchedule"]
    labels = {
      "node_group" : "gpu-workers",
      "k8s.amazonaws.com/accelerator" : "nvidia"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 5
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  },
  celeryworkers = {
    node_count = 0
    pool_name  = "celery"
    vm_size    = "Standard_D16s_v3"
    node_os    = "Linux"
    zones      = ["1"]
    taints     = ["indico.io/celery=true:NoSchedule"]
    labels = {
      "node_group" : "celery-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 20
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  },
  staticworkers = {
    node_count = 1
    pool_name  = "static"
    vm_size    = "Standard_D16s_v3"
    node_os    = "Linux"
    zones      = ["1"]
    taints     = []
    labels = {
      "node_group" : "static-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 20
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  },
  pdfworkers = {
    node_count = 1
    pool_name  = "pdf"
    vm_size    = "Standard_D16s_v3"
    node_os    = "Linux"
    zones      = ["1"]
    taints     = ["indico.io/pdfextraction=true:NoSchedule"]
    labels = {
      "node_group" : "pdf-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 5
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  },
  highmemworkers = {
    node_count = 0
    pool_name  = "highmem"
    vm_size    = "Standard_D16s_v3"
    node_os    = "Linux"
    zones      = ["1"]
    taints     = ["indico.io/highmem=true:NoSchedule"]
    labels = {
      "node_group" : "highmem-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 3
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  },
  monitoringworkers = {
    node_count = 1
    pool_name  = "monitoring"
    vm_size    = "Standard_DS11_v2"
    node_os    = "Linux"
    zones      = ["1"]
    taints     = ["indico.io/monitoring=true:NoSchedule"]
    labels = {
      "node_group" : "monitoring-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 4
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  },
  pgoworkers = {
    node_count = 1
    pool_name  = "pgo"
    vm_size    = "Standard_D16s_v3"
    node_os    = "Linux"
    zones      = ["1"]
    taints     = ["indico.io/crunchy=true:NoSchedule"]
    labels = {
      "node_group" : "pgo-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 4
    storageAccountType             = "Premium_LRS"
    image = {
      offer      = "aro4"
      publisher  = "azureopenshift"
      resourceID = ""
      sku        = "aro_410"
      version    = "410.84.20220125"
    }
  }
}
