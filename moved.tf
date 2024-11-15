moved {
  from = module.cluster.aws_iam_policy.cluster_node_iam_policy
  to   = module.iam.module.create_eks_node_role[0].aws_iam_policy.policies["${var.label}-ClusterNodePolicy"]
}

moved {
  from = module.cluster.aws_iam_policy.cluster_node_ebs_iam_policy
  to   = module.iam.module.create_eks_node_role[0].aws_iam_policy.policies["${var.label}-ClusterNodeEBSPolicy"]
}

moved {
  from = module.cluster.aws_iam_role.node_role
  to   = module.iam.module.create_eks_node_role[0].aws_iam_role.role
}
