locals {
  node_subnet_ids = slice(var.subnet_ids, 0, var.az_count)
  node_classes = {
    cpu = {
      name   = "cpu"
      ami_id = data.aws_ami.default_eks_node.id
    }
    gpu = {
      name   = "gpu"
      ami_id = data.aws_ami.gpu_eks_node.id
    }
  }

  cpu_instance_requirements = {
    instance-family = {
      key       = "karpenter.k8s.aws/instance-family"
      operator  = "In"
      values    = ["m5", "m6i", "m6a", "m7i", "m7a", "c5", "c6i", "c6a", "c7i", "c7a", "c7i-flex", "r5", "r6i", "r6a", "r7i", "r7a"]
      minValues = 16
    }
  }
  gpu_instance_requirements = {
    instance-family = {
      key       = "karpenter.k8s.aws/instance-family"
      operator  = "In"
      values    = ["g4dn"]
      minValues = 1
    }
  }
  default_node_pools = {
    static-workers = {
      type   = "cpu"
      spot   = false
      taints = []
    }
    monitoring-workers = {
      type   = "cpu"
      spot   = false
      taints = "--register-with-taints=indico.io/monitoring=true:NoSchedule"
    }
  }

  karpenter_node_pools = merge(local.default_node_pools, var.node_pools)
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = var.use_local_helm_charts ? null : var.helm_registry
  chart            = var.use_local_helm_charts ? "./charts/karpenter/" : "karpenter"
  version          = var.use_local_helm_charts ? null : var.karpenter_version
  namespace        = "karpenter"
  max_history      = 10
  create_namespace = true
  values = [<<EOF
karpenter:
  settings:
    clusterName: ${var.cluster_name}
  controller:
    resources:
      requests:
        cpu: 1
        memory: 1Gi
      limits:
        cpu: 2
        memory: 2Gi
  replicas: 1
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: Equal
      effect: NoSchedule
  nodeSelector:
    node_group: karpenter

nodeClass:
${yamlencode([for k, v in local.node_classes : {
    name             = v.name
    amiFamily        = "AL2"
    role             = var.node_role_name
    clusterName      = var.cluster_name
    amiIds           = [v.ami_id]
    subnetIds        = local.node_subnet_ids
    securityGroupIds = var.security_group_ids
    tags             = var.default_tags
    blockDeviceMappings = [{
      deviceName = "/dev/xvda"
      ebs = {
        volumeSize = var.instance_volume_size
        volumeType = var.instance_volume_type
        kmsKeyId   = split("/", var.kms_key_id)[length(split("/", var.kms_key_id)) - 1]
      }
    }]
    metadataOptions = {
      httpEndpoint            = "enabled"
      httpTokens              = "required"
      httpPutResponseHopLimit = 3
    }
    }])}

nodePool:
${yamlencode([for k, v in local.karpenter_node_pools : {
    name = k
    labels = merge({
      node_group = k
      node_pool  = k
      }, try(v.additional_labels, {}),
      try(v.additional_node_labels, "") != "" ? {
        for label in split(",", v.additional_node_labels) :
        split("=", label)[0] => split("=", label)[1]
      } : {},
      v.type == "gpu" ? {
        "k8s.amazonaws.com/accelerator" = "nvidia-tesla-t4"
    } : {})
    taints = (
      can(tostring(v.taints)) ?
      (v.taints != "" ?
        [
          length(regexall("=", split(":", trimprefix(v.taints, "--register-with-taints="))[0])) > 0 ?
          {
            key    = split("=", split(":", trimprefix(v.taints, "--register-with-taints="))[0])[0]
            value  = split("=", split(":", trimprefix(v.taints, "--register-with-taints="))[0])[1]
            effect = split(":", trimprefix(v.taints, "--register-with-taints="))[1]
          } :
          {
            key    = split(":", trimprefix(v.taints, "--register-with-taints="))[0]
            effect = split(":", trimprefix(v.taints, "--register-with-taints="))[1]
          }
        ] : []
      ) :
      (can(tolist(v.taints)) ? v.taints : [])
    )
    requirements = concat(
      [for k3, v3 in v.type == "gpu" ? local.gpu_instance_requirements : local.cpu_instance_requirements : {
        key       = v3.key
        operator  = v3.operator
        values    = v3.values
        minValues = v3.minValues
      }],
      [
        {
          key      = "karpenter.sh/capacity-type"
          operator = "In"
          values   = v.spot ? ["spot", "on-demand"] : ["on-demand"]
        },
        {
          key      = "kubernetes.io/arch"
          operator = "In"
          values   = ["amd64"]
        },
        {
          key      = "karpenter.k8s.aws/instance-cpu"
          operator = "In"
          values   = ["2", "4", "8", "16"]
        }
      ]
    )
    nodeClassRefName       = v.type
    expireAfter            = "Never"
    terminationGracePeriod = "24h"
    disruption = {
      consolidationPolicy = "WhenEmptyOrUnderutilized"
      consolidateAfter    = "1m"
    }
    limits = {
      cpu    = "1000"
      memory = "1000Gi"
    }
    weight = 10
}])}
EOF
]
}

data "aws_ami" "gpu_eks_node" {
  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-${var.k8s_version}-*"]
  }

  most_recent = true
  owners      = ["amazon"]
}

data "aws_ami" "default_eks_node" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.k8s_version}-*"]
  }

  most_recent = true
  owners      = ["amazon"]
}
