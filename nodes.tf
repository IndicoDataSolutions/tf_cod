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
      min_size         = 0
      max_size         = 20
      instance_types   = ["m5.xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "0"
      taints           = "--register-with-taints=indico.io/celery=true:NoSchedule"
    },
    static-workers = {
      min_size         = 1
      max_size         = 20
      instance_types   = ["m5.xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "0"
    },
    pdf-workers = {
      min_size         = 0
      max_size         = 3
      instance_types   = ["m5.xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "1"
      taints           = "--register-with-taints=indico.io/pdfextraction=true:NoSchedule"
    },
    highmem-workers = {
      min_size         = 0
      max_size         = 3
      instance_types   = ["m5.2xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "0"
      taints           = "--register-with-taints=indico.io/highmem=true:NoSchedule"
    },
    monitoring-workers = {
      min_size         = 1
      max_size         = 4
      instance_types   = ["m5.large"]
      type             = "cpu"
      spot             = false
      desired_capacity = "1"
      taints           = "--register-with-taints=indico.io/monitoring=true:NoSchedule"
    },
    pgo-workers = {
      min_size         = 1
      max_size         = 4
      instance_types   = ["m5.large"]
      type             = "cpu"
      spot             = false
      desired_capacity = "1"
      taints           = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
    },
    readapi-servers = {
      min_size         = 0
      max_size         = 3
      instance_types   = ["m5.2xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "0"
      taints           = "--register-with-taints=indico.io/readapi-server=true:NoSchedule"
    },
    readapi-azurite = {
      min_size         = 0
      max_size         = 1
      instance_types   = ["m5.xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "1"
      taints           = "--register-with-taints=indico.io/azurite=true:NoSchedule"
    }
  }

  insights_default_node_groups = {
    general = {
      type             = "cpu"
      spot             = false
      instance_types   = ["m5a.xlarge"]
      min_size         = 1
      max_size         = 5
      desired_capacity = "3"
    },
    pgo-workers = {
      type             = "cpu"
      spot             = false
      instance_types   = ["m5a.large"]
      min_size         = 1
      max_size         = 2
      desired_capacity = "2"
      taints           = "--register-with-taints=indico.io/crunchy=true:NoSchedule"
    },
    celery-workers = {
      type             = "cpu"
      spot             = false
      instance_types   = ["m5a.xlarge"]
      min_size         = 1
      max_size         = 3
      desired_capacity = "1"
      taints           = "--register-with-taints=indico.io/celery-workers=true:NoSchedule"
    },
    minio = {
      type             = "cpu"
      spot             = false
      instance_types   = ["t3a.xlarge"]
      min_size         = 1
      max_size         = 4
      desired_capacity = "4"
      taints           = "--register-with-taints=indico.io/minio=true:NoSchedule"
    },
    monitoring-workers = {
      min_size         = 1
      max_size         = 4
      instance_types   = ["m5.large"]
      type             = "cpu"
      spot             = false
      desired_capacity = "1"
      taints           = "--register-with-taints=indico.io/monitoring=true:NoSchedule"
    },
    weaviate = {
      type             = "cpu"
      spot             = false
      instance_types   = ["r5a.xlarge"]
      min_size         = 1
      max_size         = 3
      desired_capacity = "3"
      taints           = "--register-with-taints=indico.io/weaviate=true:NoSchedule"
    },
    weaviate-workers = {
      type             = "cpu"
      spot             = false
      instance_types   = ["c6a.2xlarge"]
      min_size         = 1
      max_size         = 4
      desired_capacity = "2"
      taints           = "--register-with-taints=indico.io/weaviate-workers=true:NoSchedule"
    }
  }

  standalone_node_groups = {
    default-workers = {
      min_size         = 1
      max_size         = 3
      instance_types   = ["m5.xlarge"]
      type             = "cpu"
      spot             = false
      desired_capacity = "0"
    }
  }
  default_node_groups = (
    var.ipa_enabled == false && var.insights_enabled == false
    ? local.standalone_node_groups
    : merge(
      var.insights_enabled ? local.insights_default_node_groups : {{}},
      var.ipa_enabled ? local.intake_default_node_groups : {{}}
    )
  )

  # This is to avoid terraform errors when the node groups variable is set,
  # as different keys make the objects incompatible for a ternary function. 
  # To solve this, we set it to null which matches all types
  default_node_groups_logic = var.node_groups == null ? local.default_node_groups : tomap(null)

  variable_node_groups = var.node_groups != null ? var.node_groups : tomap(null)

  node_groups = merge(local.default_node_groups_logic, local.variable_node_groups)
}
