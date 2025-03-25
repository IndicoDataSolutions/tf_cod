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
    celery-workers = {
      min_size               = 0
      max_size               = 20
      instance_types         = ["m5.xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "0"
      taints                 = "--register-with-taints=indico.io/celery=true:NoSchedule"
      additional_node_labels = ""
    },
    static-workers = {
      min_size               = 1
      max_size               = 20
      instance_types         = ["m5.xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "0"
      additional_node_labels = ""
      taints                 = ""
    },
    pdf-workers = {
      min_size               = 0
      max_size               = 3
      instance_types         = ["m5.xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "1"
      taints                 = "--register-with-taints=indico.io/pdfextraction=true:NoSchedule"
      additional_node_labels = ""
    },
    highmem-workers = {
      min_size               = 0
      max_size               = 3
      instance_types         = ["m5.2xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "0"
      taints                 = "--register-with-taints=indico.io/highmem=true:NoSchedule"
      additional_node_labels = ""
    },
    monitoring-workers = {
      min_size               = 1
      max_size               = 4
      instance_types         = ["m5.large"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "1"
      taints                 = "--register-with-taints=indico.io/monitoring=true:NoSchedule"
      additional_node_labels = ""
    },
    pgo-workers = {
      min_size               = 1
      max_size               = 4
      instance_types         = ["m5.large"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "1"
      taints                 = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
      additional_node_labels = ""
    },
    readapi-servers = {
      min_size               = 0
      max_size               = 3
      instance_types         = ["m5.2xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "0"
      taints                 = "--register-with-taints=indico.io/readapi-server=true:NoSchedule"
      additional_node_labels = ""
    },
    readapi-azurite = {
      min_size               = 0
      max_size               = 1
      instance_types         = ["m5.xlarge"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "1"
      taints                 = "--register-with-taints=indico.io/azurite=true:NoSchedule"
      additional_node_labels = ""
    }
  }

  insights_default_node_groups = {
    general = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["m5a.xlarge"]
      min_size               = 1
      max_size               = 5
      desired_capacity       = "3"
      additional_node_labels = ""
      taints                 = ""
    },
    pgo-workers = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["m5a.large"]
      min_size               = 1
      max_size               = 2
      desired_capacity       = "2"
      taints                 = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
      additional_node_labels = ""
    },
    celery-workers = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["m5a.xlarge"]
      min_size               = 1
      max_size               = 3
      desired_capacity       = "1"
      taints                 = "--register-with-taints=indico.io/celery-workers=true:NoSchedule"
      additional_node_labels = ""
    },
    minio = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["t3a.xlarge"]
      min_size               = 1
      max_size               = 4
      desired_capacity       = "4"
      taints                 = "--register-with-taints=indico.io/minio=true:NoSchedule"
      additional_node_labels = ""
    },
    monitoring-workers = {
      min_size               = 1
      max_size               = 4
      instance_types         = ["m5.large"]
      type                   = "cpu"
      spot                   = false
      desired_capacity       = "1"
      taints                 = "--register-with-taints=indico.io/monitoring=true:NoSchedule"
      additional_node_labels = ""
    },
    weaviate = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["r5a.xlarge"]
      min_size               = 1
      max_size               = 3
      desired_capacity       = "3"
      taints                 = "--register-with-taints=indico.io/weaviate=true:NoSchedule"
      additional_node_labels = ""
    },
    weaviate-workers = {
      type                   = "cpu"
      spot                   = false
      instance_types         = ["c6a.2xlarge"]
      min_size               = 1
      max_size               = 4
      desired_capacity       = "2"
      taints                 = "--register-with-taints=indico.io/weaviate-workers=true:NoSchedule"
      additional_node_labels = ""
    }
  }

  standalone_node_groups = {
    default-workers = {
      min_size               = 1
      max_size               = 3
      instance_types         = ["m5.xlarge"]
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

  # This is to avoid terraform errors when the node groups variable is set,
  # as different keys make the objects incompatible for a ternary function. 
  # To solve this, we set it to null which matches all types
  default_node_groups_logic = var.node_groups == null && var.karpenter_enabled == false ? local.default_node_groups : tomap(null)

  variable_node_groups = var.node_groups != null && var.karpenter_enabled == false ? var.node_groups : tomap(null)

  karpenter_node_group_logic = var.karpenter_enabled ? local.karpenter_node_group : tomap(null)

  node_groups = merge(local.default_node_groups_logic, local.variable_node_groups, local.karpenter_node_group_logic)

  default_node_pools_logic = var.node_groups == null ? local.default_node_groups : tomap(null)

  variable_node_pools = var.node_groups != null ? var.node_groups : tomap(null)

  node_pools = merge(local.default_node_pools_logic, local.variable_node_pools)
}
