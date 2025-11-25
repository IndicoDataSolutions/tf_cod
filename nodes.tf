locals {


  intake_default_node_groups = {
    gpu-workers = {
      min_size               = 0
      max_size               = 5
      instance_types         = ["g4dn.xlarge"]
      type                   = "gpu"
      spot                   = false
      desired_capacity       = "0"
      additional_node_labels = "group=gpu-enabled"
      taints                 = "--register-with-taints=nvidia.com/gpu=true:NoSchedule"
    },
    static-workers = {
      min_size               = 1
      max_size               = 20
      instance_types         = ["m6a.4xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "0"
      additional_node_labels = ""
      taints                 = ""
    }
  }

  insights_default_node_groups = {
    static-workers = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["m6a.4xlarge"]
      min_size               = 1
      max_size               = 10
      desired_capacity       = "1"
      additional_node_labels = ""
      taints                 = ""
    }
  }

  standalone_node_groups = {
    default-workers = {
      min_size               = 1
      max_size               = 3
      instance_types         = ["m6.xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "0"
      additional_node_labels = ""
      taints                 = ""
    }
  }

  karpenter_node_group = {
    karpenter = {
      type             = "cpu"
      spot             = false
      instance_types   = ["c6a.large"]
      min_size         = 1
      max_size         = 1
      desired_capacity = "1"
      taints           = "--register-with-taints=node-role.kubernetes.io/control-plane:NoSchedule"
    }
  }

  default_node_groups = (
    var.ipa_enabled == false && var.insights_enabled == false && var.karpenter_enabled == false
    ? local.standalone_node_groups
    : merge(
      var.insights_enabled ? local.insights_default_node_groups : tomap(null),
      var.ipa_enabled ? local.intake_default_node_groups : tomap(null)
    )
  )

  on_prem_test_node_groups = var.on_prem_test == true ? {
    pgo-workers = {
      min_size               = 2
      max_size               = 4
      instance_types         = ["m6a.large"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "2"
      taints                 = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
      additional_node_labels = ""
      postgres_volume_size   = substr(var.postgres_volume_size, 0, length(var.postgres_volume_size) - 2)
    }
  } : tomap(null)

  # This is to avoid terraform errors when the node groups variable is set,
  # as different keys make the objects incompatible for a ternary function. 
  # To solve this, we set it to null which matches all types
  default_node_groups_logic = var.node_groups == null && var.karpenter_enabled == false ? local.default_node_groups : tomap(null)

  variable_node_groups = var.node_groups != null && var.karpenter_enabled == false ? var.node_groups : tomap(null)

  karpenter_node_group_logic = var.karpenter_enabled ? local.karpenter_node_group : tomap(null)

  node_groups = merge(local.default_node_groups_logic, local.variable_node_groups, local.karpenter_node_group_logic, local.on_prem_test_node_groups)

  default_node_pools_logic = var.node_groups == null ? local.default_node_groups : tomap(null)

  variable_node_pools = var.node_groups != null ? var.node_groups : tomap(null)

  node_pools = merge(local.default_node_pools_logic, local.variable_node_pools)
}
