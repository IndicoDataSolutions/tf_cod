locals {
  aks_default_node_pool = {
    name                        = "defaultpool"
    node_count                  = 3
    vm_size                     = "Standard_D16s_v5"
    zones                       = ["1", "2"]
    taints                      = null
    temporary_name_for_rotation = "temppool"
    labels = {
      "node_group" : "default-workers"
    }
    cluster_auto_scaling           = true
    cluster_auto_scaling_min_count = 1
    cluster_auto_scaling_max_count = 5
  }

  aks_default_node_pool_logic = var.default_node_pool == null ? local.aks_default_node_pool : null

  default_node_pool = var.default_node_pool == null ? local.aks_default_node_pool_logic : var.default_node_pool

  intake_default_node_pools = {
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
      vm_size    = "Standard_D16s_v5"
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
      vm_size    = "Standard_D16s_v5"
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
      vm_size    = "Standard_D16s_v5"
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
      vm_size    = "Standard_D16s_v5"
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
      vm_size    = "Standard_D4s_v5"
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
      vm_size    = "Standard_D16s_v5"
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
      vm_size    = "Standard_D16s_v5"
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

  insights_default_node_pools = {
    general = {
      node_count = 3
      pool_name  = "general"
      vm_size    = "Standard_D16s_v5"
      node_os    = "Linux"
      zones      = ["1", "2"]
      taints     = []
      labels = {
        "node_group" : "general"
      }
      cluster_auto_scaling           = true
      cluster_auto_scaling_min_count = 1
      cluster_auto_scaling_max_count = 5
    },
    pgoworkers = {
      node_count = 1
      pool_name  = "pgo"
      vm_size    = "Standard_D16s_v5"
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
    celeryworkers = {
      node_count = 0
      pool_name  = "celery"
      vm_size    = "Standard_D16s_v5"
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
    minio = {
      node_count = 0
      pool_name  = "minio"
      vm_size    = "Standard_D16s_v5"
      node_os    = "Linux"
      zones      = ["1", "2"]
      taints     = ["indico.io/minio=true:NoSchedule"]
      labels = {
        "node_group" : "minio"
      }
      cluster_auto_scaling           = true
      cluster_auto_scaling_min_count = 0
      cluster_auto_scaling_max_count = 4
    },
    monitoringworkers = {
      node_count = 1
      pool_name  = "monitoring"
      vm_size    = "Standard_D4s_v5"
      node_os    = "Linux"
      zones      = ["1", "2"]
      taints     = ["indico.io/monitoring=true:NoSchedule"]
      labels = {
        "node_group" : "monitoring-workers"
      }
      cluster_auto_scaling           = true
      cluster_auto_scaling_min_count = 1
      cluster_auto_scaling_max_count = 4
    }
  }

  default_node_pools = merge((var.insights_enabled ? local.insights_default_node_pools : null), (var.ipa_enabled ? local.intake_default_node_pools : null))

  # This is to avoid terraform errors when the node groups variable is set,
  # as different keys make the objects incompatible for a ternary function. 
  # To solve this, we set it to null which matches all types
  default_node_pools_logic = var.additional_node_pools == null ? local.default_node_pools : null 

  additional_node_pools = var.additional_node_pools == null ? local.default_node_pools_logic : var.additional_node_pools 
}