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

moved {
  from = module.cluster
  to   = module.cluster[0]
}

# Moved blocks for modules that had count added in application.tf

moved {
  from = module.indico-common
  to   = module.indico-common[0]
}

#changes for multitenant
moved {
  from = random_password.password
  to   = random_password.password[0]
}

moved {
  from = random_password.salt
  to   = random_password.salt[0]
}

moved {
  from = random_password.hash
  to   = random_password.hash[0]
}

moved {
  from = htpasswd_password.hash
  to   = htpasswd_password.hash[0]
}

moved {
  from = random_password.monitoring-password
  to   = random_password.monitoring-password[0]
}

# Migrate from public_networking (v1.2) to networking (v2.x) with network_type = "create"
# so Terraform moves resources in state instead of destroying/recreating the VPC.
moved {
  from = module.public_networking[0].aws_vpc.indico
  to   = module.networking[0].module.create_network[0].aws_vpc.indico
}

# Subnets: public_networking -> networking create_network (avoid CIDR conflict on create)
moved {
  from = module.public_networking[0].aws_subnet.indico_private_subnets["10.0.0.0/19"]
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_private_subnets["10.0.0.0/19"]
}
moved {
  from = module.public_networking[0].aws_subnet.indico_private_subnets["10.0.32.0/19"]
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_private_subnets["10.0.32.0/19"]
}
moved {
  from = module.public_networking[0].aws_subnet.indico_private_subnets["10.0.64.0/19"]
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_private_subnets["10.0.64.0/19"]
}
moved {
  from = module.public_networking[0].aws_subnet.indico_public_subnets["10.0.96.0/27"]
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_public_subnets["10.0.96.0/27"]
}
moved {
  from = module.public_networking[0].aws_subnet.indico_public_subnets["10.0.97.0/27"]
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_public_subnets["10.0.97.0/27"]
}
moved {
  from = module.public_networking[0].aws_subnet.indico_public_subnets["10.0.98.0/27"]
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_public_subnets["10.0.98.0/27"]
}
