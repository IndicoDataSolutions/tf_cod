is_openshift          = true
include_external_dns  = false
use_workload_identity = false

svp_client_id     = "na"
svp_client_secret = "na"

# fill out this file with desired values and reference it 

region                  = "eastus"
vnet_cidr               = "192.168.0.0/20"
subnet_cidrs            = ["192.168.0.0/22"]
worker_subnet_cidrs     = ["192.168.4.0/26"]
storage_account_name    = "indicodatatest"
cluster_manager_vm_size = "Standard_F2s"
private_cluster_enabled = false

default_node_pool = {
  name                           = "defaultpool"
  node_count                     = 3
  vm_size                        = "Standard_D16_v3"
  zones                          = ["1", "2"]
  taints                         = null
  cluster_auto_scaling           = false
  cluster_auto_scaling_min_count = null
  cluster_auto_scaling_max_count = null
}

additional_node_pools = {
  gpuworkers = {
    node_count = 0
    pool_name  = "gpu"
    vm_size    = "Standard_NC4as_T4_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["nvidia.com/gpu=true:NoSchedule"]
    labels = {
      "node_group" : "gpu-workers",
      "k8s.amazonaws.com/accelerator" : "nvidia"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 5
    storageAccountType             = "StandardSSD_LRS"
  },
  celeryworkers = {
    node_count = 0
    pool_name  = "celery"
    vm_size    = "Standard_D16_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["indico.io/celery=true:NoSchedule"]
    labels = {
      "node_group" : "celery-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 20
    storageAccountType             = "StandardSSD_LRS"
  },
  staticworkers = {
    node_count = 1
    pool_name  = "static"
    vm_size    = "Standard_D16_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = []
    labels = {
      "node_group" : "static-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 20
    storageAccountType             = "StandardSSD_LRS"
  },
  pdfworkers = {
    node_count = 1
    pool_name  = "pdf"
    vm_size    = "Standard_D16_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["indico.io/pdfextraction=true:NoSchedule"]
    labels = {
      "node_group" : "pdf-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 5
    storageAccountType             = "StandardSSD_LRS"
  },
  highmemworkers = {
    node_count = 0
    pool_name  = "highmem"
    vm_size    = "Standard_D16_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["indico.io/highmem=true:NoSchedule"]
    labels = {
      "node_group" : "highmem-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 3
    storageAccountType             = "StandardSSD_LRS"
  },
  monitoringworkers = {
    node_count = 1
    pool_name  = "monitoring"
    vm_size    = "Standard_d11_v2"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["indico.io/monitoring=true:NoSchedule"]
    labels = {
      "node_group" : "monitoring-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 4
    storageAccountType             = "StandardSSD_LRS"
  },
  pgoworkers = {
    node_count = 1
    pool_name  = "pgo"
    vm_size    = "Standard_D16_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["indico.io/crunchy=true:NoSchedule"]
    labels = {
      "node_group" : "pgo-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 4
    storageAccountType             = "StandardSSD_LRS"
  }
}
