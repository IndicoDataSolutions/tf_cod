# fill out this file with desired values and reference it 

label                   = "example-label"
region                  = "eastus"
vnet_cidr               = "192.168.0.0/20"
subnet_cidrs            = ["192.168.0.0/22"]
database_subnet_cidr    = ["192.168.4.0/26"]
storage_account_name    = "indicodatatest"
cluster_manager_vm_size = "Standard_F2s"
private_cluster_enabled = true

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
