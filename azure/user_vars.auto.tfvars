


# fill out this file with desired values and reference it

region                  = "eastus"
vnet_cidr               = "192.168.0.0/20"
subnet_cidrs            = ["192.168.0.0/22"]
storage_account_name    = ""
private_cluster_enabled = false
k8s_version             = "1.29.4"

default_node_pool = {
  name       = "defaultpool"
  node_count = 3
  vm_size    = "Standard_D16_v3"
  zones      = ["1", "2"]
  taints     = null
  labels = {
    "node_group" : "default-workers"
  }
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
    zones      = ["0"]
    taints     = ["nvidia.com/gpu=true:NoSchedule"]
    labels = {
      "node_group" : "gpu-workers",
      "k8s.amazonaws.com/accelerator" : "nvidia"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 5
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
  },
  azurite = {
    node_count = 1
    pool_name  = "azurite"
    vm_size    = "Standard_D16_v3"
    node_os    = "Linux"
    zones      = ["1", "2"]
    taints     = ["indico.io/azurite=true:NoSchedule"]
    labels = {
      "node_group" : "readapi-azurite"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 0
    cluster_auto_scaling_max_count = 1
  }
}
