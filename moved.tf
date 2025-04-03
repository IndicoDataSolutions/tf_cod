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
  from = module.public_networking[0]
  to   = module.networking[0]
}

# If you have specific resources that need individual moves, you might also need:
moved {
  from = module.public_networking[0].indico_vpc_id
  to   = module.networking[0].indico_vpc_id
}

moved {
  from = module.public_networking[0].private_subnet_ids
  to   = module.networking[0].private_subnet_ids
}

moved {
  from = module.public_networking[0].private_subnet_ids
  to   = module.networking[0].private_subnet_ids
}