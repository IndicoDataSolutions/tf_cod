


# fill out this file with desired values and reference it 

region                  = "eastus"
vnet_cidr               = "192.168.0.0/20"
subnet_cidrs            = ["192.168.0.0/22"]
database_subnet_cidr    = ["192.168.4.0/26"]
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
  gpupool = {
    node_count                     = 3
    pool_name                      = "gpupool"
    vm_size                        = "Standard_NC4as_T4_v3"
    zones                          = ["1", "2"]
    node_os                        = "Linux"
    taints                         = null
    cluster_auto_scaling           = false
    cluster_auto_scaling_min_count = null
    cluster_auto_scaling_max_count = null
  }
  /*
  node_groups = [
  {
    min_size         = 0
    max_size         = 5
    instance_types   = ["g4dn.xlarge"]
    name             = "gpu-workers" # for gpu workloads
    type             = "gpu"
    spot             = false
    desired_capacity = "0"
  },
  {
    min_size         = 0
    max_size         = 20
    instance_types   = ["m5.xlarge"]
    name             = "celery-workers" # for pods that we want to autoscale
    type             = "cpu"
    spot             = true
    desired_capacity = "0"
  },
  {
    min_size         = 1
    max_size         = 20
    instance_types   = ["m5.xlarge"]
    name             = "static-workers" # for pods that need to be on stable nodes.
    type             = "cpu"
    spot             = false
    desired_capacity = "0"
  },
  {
    min_size         = 0
    max_size         = 3
    instance_types   = ["m5.xlarge"]
    name             = "pdf-workers" # for pods that need to be on stable nodes.
    type             = "cpu"
    spot             = false
    desired_capacity = "1"
  },
  {
    min_size         = 0
    max_size         = 3
    instance_types   = ["m5.2xlarge"]
    name             = "highmem-workers" # for autoscaling pods that have high memory demands.
    type             = "cpu"
    spot             = false
    desired_capacity = "0"
  },
  {
    min_size         = 1
    max_size         = 9
    instance_types   = ["t2.medium"]
    name             = "monitoring-workers" # for autoscaling pods that have high memory demands.
    type             = "cpu"
    spot             = false
    desired_capacity = "3"
  },
  {
    min_size         = 1
    max_size         = 4
    instance_types   = ["m5.large"]
    name             = "pgo-workers" # for pods that we want to autoscale
    type             = "cpu"
    spot             = false
    desired_capacity = "1"
    taints           = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
  }
  */
  ## an example additonal node pool
  #   pool3 = {
  #     node_count                     = 4
  #     vm_size                        = "Standard_E4_v3"
  #     zones                          = ["1", "2", "3"]
  #     node_os                        = "Linux"
  #     taints                         = null
  #     cluster_auto_scaling           = true
  #     cluster_auto_scaling_min_count = 4
  #     cluster_auto_scaling_max_count = 12
  #   }
}
