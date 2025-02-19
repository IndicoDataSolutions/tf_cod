data "aws_iam_policy_document" "karpenter_controller_policy" {
  statement {
    actions = [
      "ssm:GetParameter",
      "ec2:DescribeImages",
      "ec2:RunInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateTags",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:DescribeSpotPriceHistory",
      "pricing:GetProducts"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:TerminateInstances"
    ]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }
  statement {
    actions = [
      "iam:PassRole"
    ]
    effect    = "Allow"
    resources = ["${var.node_role_arn}"]
  }
  statement {
    actions = [
      "eks:DescribeCluster"
    ]
    effect    = "Allow"
    resources = ["arn:aws:eks:${var.region}:${var.account_id}:cluster/${var.cluster_name}"]
  }
  statement {
    actions = [
      "iam:CreateInstanceProfile"
    ]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = ["${var.region}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }
  statement {
    actions = [
      "iam:TagInstanceProfile"
    ]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = ["${var.region}"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = ["${var.region}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }
  statement {
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile"
    ]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = ["${var.region}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }
  statement {
    actions = [
      "iam:GetInstanceProfile"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name        = "${var.cluster_name}-karpenter-controller-policy"
  description = "Policy for the Karpenter controller"
  policy      = data.aws_iam_policy_document.karpenter_controller_policy.json
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy_attachment" {
  role       = var.node_role_name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

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
    instance-category = {
      key      = "karpenter.k8s.aws/instance-category"
      operator = "In"
      values   = ["c", "m", "r"]
    }
    instance-family = {
      key      = "karpenter.k8s.aws/instance-family"
      operator = "In"
      values   = ["c", "m", "r"]
    }
    arch = {
      key      = "karpenter.k8s.aws/arch"
      operator = "In"
      values   = ["amd64"]
    }
  }

  default_node_pools = {
    static-workers = {
      spot   = false
      taints = {}
    }
  }

  karpenter_node_pools = concat(local.default_node_pools, var.node_pools)

}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = var.helm_registry
  chart            = "karpenter"
  version          = var.karpenter_version
  namespace        = "karpenter"
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
    securityGroupIds = [var.cluster_security_group_id]
    tags             = var.default_tags
    blockDeviceMappings = [{
      deviceName = "/dev/xvda"
      ebs = {
        volumeSize = var.instance_volume_size
        volumeType = var.instance_volume_type
        kmsKeyId   = split("/", var.kms_key_id)[length(split("/", var.kms_key_id)) - 1]
      }
    }]
    }])}

nodePool:
${yamlencode([for k, v in local.karpenter_node_pools : {
    name = k
    lables = {
      node_group = k
      node_pool  = k
    }
    taints = [for k2, v2 in v.taints : {
      key    = v2.key
      value  = v2.value
      effect = v2.effect
    }]
    requirements = concat(
      [for k3, v3 in local.cpu_instance_requirements : {
        key      = v3.key
        operator = v3.operator
        values   = v3.values
      }],
      [{
        key      = "karpenter.k8s.aws/capacity-type"
        operator = "In"
        values   = v.spot ? ["spot", "on-demand"] : ["on-demand"]
      }]
    )
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

