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
moved {
  from = module.public_networking[0].aws_eip.indico_elastic_ip
  to   = module.networking[0].module.create_network[0].aws_eip.indico_elastic_ip
}
moved {
  from = module.public_networking[0].aws_subnet.indico_private_subnets
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_private_subnets
}
moved {
  from = module.public_networking[0].aws_subnet.indico_public_subnets
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_public_subnets
}
moved {
  from = module.public_networking[0].aws_subnet.indico_firewall_subnets
  to   = module.networking[0].module.create_network[0].aws_subnet.indico_firewall_subnets
}
moved {
  from = module.public_networking[0].aws_internet_gateway.indico_igw
  to   = module.networking[0].module.create_network[0].aws_internet_gateway.indico_igw
}
moved {
  from = module.public_networking[0].aws_route_table.public_route_table
  to   = module.networking[0].module.create_network[0].aws_route_table.public_route_table
}
moved {
  from = module.public_networking[0].aws_route_table.private_route_table
  to   = module.networking[0].module.create_network[0].aws_route_table.private_route_table
}
moved {
  from = module.public_networking[0].aws_route_table.firewall_route_table
  to   = module.networking[0].module.create_network[0].aws_route_table.firewall_route_table
}
moved {
  from = module.public_networking[0].aws_route_table.igw_route_table
  to   = module.networking[0].module.create_network[0].aws_route_table.igw_route_table
}
moved {
  from = module.public_networking[0].aws_route_table_association.public_rt_associations
  to   = module.networking[0].module.create_network[0].aws_route_table_association.public_rt_associations
}
moved {
  from = module.public_networking[0].aws_route_table_association.firewall_rt_associations
  to   = module.networking[0].module.create_network[0].aws_route_table_association.firewall_rt_associations
}
moved {
  from = module.public_networking[0].aws_route_table_association.private_associations
  to   = module.networking[0].module.create_network[0].aws_route_table_association.private_associations
}
moved {
  from = module.public_networking[0].aws_route_table_association.igw_rt_associations
  to   = module.networking[0].module.create_network[0].aws_route_table_association.igw_rt_associations
}
moved {
  from = module.public_networking[0].aws_nat_gateway.nat_gw
  to   = module.networking[0].module.create_network[0].aws_nat_gateway.nat_gw
}
moved {
  from = module.public_networking[0].aws_vpc_endpoint.gateway-endpoints
  to   = module.networking[0].module.create_network[0].aws_vpc_endpoint.gateway-endpoints
}
moved {
  from = module.public_networking[0].aws_vpc_endpoint.s3-endpoint
  to   = module.networking[0].module.create_network[0].aws_vpc_endpoint.s3-endpoint
}
moved {
  from = module.public_networking[0].null_resource.region_validation
  to   = module.networking[0].module.create_network[0].null_resource.region_validation
}
moved {
  from = module.public_networking[0].aws_default_security_group.default
  to   = module.networking[0].module.create_network[0].aws_default_security_group.default
}
moved {
  from = module.public_networking[0].aws_security_group.indico_all_subnets
  to   = module.networking[0].module.create_network[0].aws_security_group.indico_all_subnets
}
moved {
  from = module.public_networking[0].aws_networkfirewall_firewall.firewall
  to   = module.networking[0].module.create_network[0].aws_networkfirewall_firewall.firewall
}
moved {
  from = module.public_networking[0].aws_networkfirewall_firewall_policy.firewall-policy
  to   = module.networking[0].module.create_network[0].aws_networkfirewall_firewall_policy.firewall-policy
}
moved {
  from = module.public_networking[0].aws_networkfirewall_rule_group.allow_domains
  to   = module.networking[0].module.create_network[0].aws_networkfirewall_rule_group.allow_domains
}
moved {
  from = module.public_networking[0].aws_flow_log.indico_flow_logs
  to   = module.networking[0].module.create_network[0].aws_flow_log.indico_flow_logs
}
moved {
  from = module.public_networking[0].aws_cloudwatch_log_group.indico_flow_logs
  to   = module.networking[0].module.create_network[0].aws_cloudwatch_log_group.indico_flow_logs
}
moved {
  from = module.public_networking[0].aws_security_group.indico_allow_nginx_ingress_access
  to   = module.networking[0].module.create_network[0].aws_security_group.indico_allow_nginx_ingress_access
}



