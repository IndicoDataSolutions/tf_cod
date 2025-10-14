moved {
  from = module.cluster.aws_iam_policy.cluster_node_ebs_iam_policy
  to   = module.iam.module.create_eks_node_role[0].aws_iam_policy.policies[0]
}

moved {
  from = module.cluster.aws_iam_policy.cluster_node_iam_policy
  to   = module.iam.module.create_eks_node_role[0].aws_iam_policy.policies[1]
}

moved {
  from = module.cluster.aws_iam_role.node_role
  to   = module.iam.module.create_eks_node_role[0].aws_iam_role.role
}

moved {
  from = github_repository_file.argocd-application-yaml[0]
  to   = module.intake[0].module.intake_application.github_repository_file.argocd-application-yaml[0]
}

moved {
  from = github_repository_file.crds-values-yaml[0]
  to   = module.indico-common.github_repository_file.crds_values_yaml[0]
}

moved {
  from = github_repository_file.pre-reqs-values-yaml[0]
  to   = module.intake[0].github_repository_file.pre_reqs_values_yaml[0]
}

moved {
  from = github_repository_file.smoketest-application-yaml[0]
  to   = module.intake_smoketests[0].github_repository_file.argocd-application-yaml[0]
}

moved {
  from = helm_release.ipa-pre-requisites
  to   = module.intake[0].helm_release.ipa-pre-requisites
}

moved {
  from = helm_release.monitoring[0]
  to   = module.indico-common.helm_release.monitoring[0]
}

moved {
  from = module.cluster.aws_iam_role_policy_attachment.ebs_cluster_policy
  to   = module.iam.module.create_eks_node_role[0].aws_iam_role_policy_attachment.attachments[0]
}

moved {
  from = module.cluster.aws_iam_role_policy_attachment.additional_cluster_policy
  to   = module.iam.module.create_eks_node_role[0].aws_iam_role_policy_attachment.attachments[1]
}

moved {
  from = module.cluster.aws_iam_role_policy_attachment.additional["IAMReadOnlyAccess"]
  to   = module.iam.module.create_eks_node_role[0].aws_iam_role_policy_attachment.additional_policies[0]
}

moved {
  from = module.s3-storage
  to   = module.s3-storage[0]
}

moved {
  from = module.fsx-storage
  to   = module.fsx-storage[0]
}

moved {
  from = module.efs-storage
  to   = module.efs-storage[0]
}

moved {
  from = module.iam
  to   = module.iam[0]
}

moved {
  from = module.network
  to   = module.network[0]
}

moved {
  from = module.kms_key
  to   = module.kms_key[0]
}


moved {
  from = module.sqs_sns
  to   = module.sqs_sns[0]
}

# Move statements for module.cluster.module.indico_cluster resources
moved {
  from = module.cluster.module.indico_cluster.data.aws_caller_identity.current[0]
  to   = module.cluster.module.indico_cluster[0].data.aws_caller_identity.current
}

moved {
  from = module.cluster.module.indico_cluster.data.aws_eks_addon_version.this["coredns"]
  to   = module.cluster.module.indico_cluster[0].data.aws_eks_addon_version.this["coredns"]
}

moved {
  from = module.cluster.module.indico_cluster.data.aws_eks_addon_version.this["kube-proxy"]
  to   = module.cluster.module.indico_cluster[0].data.aws_eks_addon_version.this["kube-proxy"]
}

moved {
  from = module.cluster.module.indico_cluster.data.aws_eks_addon_version.this["vpc-cni"]
  to   = module.cluster.module.indico_cluster[0].data.aws_eks_addon_version.this["vpc-cni"]
}

moved {
  from = module.cluster.module.indico_cluster.data.aws_iam_session_context.current[0]
  to   = module.cluster.module.indico_cluster[0].data.aws_iam_session_context.current
}

moved {
  from = module.cluster.module.indico_cluster.data.aws_partition.current[0]
  to   = module.cluster.module.indico_cluster[0].data.aws_partition.current
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/argo_branch"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/argo_branch"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/argo_path"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/argo_path"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/argo_repo"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/argo_repo"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/cluster"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/cluster"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/cod"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/cod"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/customer"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/customer"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_ec2_tag.cluster_primary_security_group["indico/environment"]
  to   = module.cluster.module.indico_cluster[0].aws_ec2_tag.cluster_primary_security_group["indico/environment"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_eks_addon.this["coredns"]
  to   = module.cluster.module.indico_cluster[0].aws_eks_addon.this["coredns"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_eks_addon.this["kube-proxy"]
  to   = module.cluster.module.indico_cluster[0].aws_eks_addon.this["kube-proxy"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_eks_addon.this["vpc-cni"]
  to   = module.cluster.module.indico_cluster[0].aws_eks_addon.this["vpc-cni"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_eks_cluster.this[0]
  to   = module.cluster.module.indico_cluster[0].aws_eks_cluster.this
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group.cluster[0]
  to   = module.cluster.module.indico_cluster[0].aws_security_group.cluster
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group.node[0]
  to   = module.cluster.module.indico_cluster[0].aws_security_group.node
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.cluster["egress_nodes_ephemeral_ports_tcp"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.cluster["egress_nodes_ephemeral_ports_tcp"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.cluster["ingress_nodes_443"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.cluster["ingress_nodes_443"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["egress_all"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["egress_all"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_443"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_443"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_4443_webhook"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_4443_webhook"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_6443_webhook"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_6443_webhook"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_8443_webhook"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_8443_webhook"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_9443_webhook"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_9443_webhook"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_kubelet"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_kubelet"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_cluster_to_node_all_traffic"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_cluster_to_node_all_traffic"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_nodes_ephemeral"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_nodes_ephemeral"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_self_all"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_self_all"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_self_coredns_tcp"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_self_coredns_tcp"]
}

moved {
  from = module.cluster.module.indico_cluster.aws_security_group_rule.node["ingress_self_coredns_udp"]
  to   = module.cluster.module.indico_cluster[0].aws_security_group_rule.node["ingress_self_coredns_udp"]
}

moved {
  from = module.cluster.module.indico_cluster.time_sleep.this[0]
  to   = module.cluster.module.indico_cluster[0].time_sleep.this
}

