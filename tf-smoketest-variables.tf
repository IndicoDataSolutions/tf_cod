resource "kubernetes_config_map" "terraform-variables" {
  # this file is generated via pre-commit, DO NOT EDIT !
    depends_on = [null_resource.wait-for-tf-cod-chart-build]
    metadata {
      name = "terraform-variables"
    }
    data = {
      is_azure = "${jsonencode(var.is_azure)}"
    is_aws = "${jsonencode(var.is_aws)}"
    label = "${jsonencode(var.label)}"
    environment = "${jsonencode(var.environment)}"
    message = "${jsonencode(var.message)}"
    applications = "${jsonencode(var.applications)}"
    region = "${jsonencode(var.region)}"
    direct_connect = "${jsonencode(var.direct_connect)}"
    additional_tags = "${jsonencode(var.additional_tags)}"
    default_tags = "${jsonencode(var.default_tags)}"
    vpc_cidr = "${jsonencode(var.vpc_cidr)}"
    public_ip = "${jsonencode(var.public_ip)}"
    vpc_name = "${jsonencode(var.vpc_name)}"
    private_subnet_cidrs = "${jsonencode(var.private_subnet_cidrs)}"
    public_subnet_cidrs = "${jsonencode(var.public_subnet_cidrs)}"
    subnet_az_zones = "${jsonencode(var.subnet_az_zones)}"
    storage_gateway_size = "${jsonencode(var.storage_gateway_size)}"
    existing_kms_key = "${jsonencode(var.existing_kms_key)}"
    bucket_versioning = "${jsonencode(var.bucket_versioning)}"
    submission_expiry = "${jsonencode(var.submission_expiry)}"
    uploads_expiry = "${jsonencode(var.uploads_expiry)}"
    name = "${jsonencode(var.name)}"
    cluster_name = "${jsonencode(var.cluster_name)}"
    k8s_version = "${jsonencode(var.k8s_version)}"
    node_groups = "${jsonencode(var.node_groups)}"
    node_bootstrap_arguments = "${jsonencode(var.node_bootstrap_arguments)}"
    node_user_data = "${jsonencode(var.node_user_data)}"
    node_disk_size = "${jsonencode(var.node_disk_size)}"
    cluster_node_policies = "${jsonencode(var.cluster_node_policies)}"
    kms_encrypt_secrets = "${jsonencode(var.kms_encrypt_secrets)}"
    enable_readapi = "${jsonencode(var.enable_readapi)}"
    azure_readapi_client_id = "${jsonencode(var.azure_readapi_client_id)}"
    azure_readapi_subscription_id = "${jsonencode(var.azure_readapi_subscription_id)}"
    azure_readapi_tenant_id = "${jsonencode(var.azure_readapi_tenant_id)}"
    azure_indico_io_client_id = "${jsonencode(var.azure_indico_io_client_id)}"
    azure_indico_io_subscription_id = "${jsonencode(var.azure_indico_io_subscription_id)}"
    azure_indico_io_tenant_id = "${jsonencode(var.azure_indico_io_tenant_id)}"
    eks_cluster_iam_role = "${jsonencode(var.eks_cluster_iam_role)}"
    eks_cluster_nodes_iam_role = "${jsonencode(var.eks_cluster_nodes_iam_role)}"
    storage_capacity = "${jsonencode(var.storage_capacity)}"
    deletion_protection_enabled = "${jsonencode(var.deletion_protection_enabled)}"
    skip_final_snapshot = "${jsonencode(var.skip_final_snapshot)}"
    per_unit_storage_throughput = "${jsonencode(var.per_unit_storage_throughput)}"
    az_count = "${jsonencode(var.az_count)}"
    snapshot_id = "${jsonencode(var.snapshot_id)}"
    include_rox = "${jsonencode(var.include_rox)}"
    aws_account = "${jsonencode(var.aws_account)}"
    argo_enabled = "${jsonencode(var.argo_enabled)}"
    argo_host = "${jsonencode(var.argo_host)}"
    argo_repo = "${jsonencode(var.argo_repo)}"
    argo_branch = "${jsonencode(var.argo_branch)}"
    argo_namespace = "${jsonencode(var.argo_namespace)}"
    argo_path = "${jsonencode(var.argo_path)}"
    argo_github_team_owner = "${jsonencode(var.argo_github_team_owner)}"
    ipa_repo = "${jsonencode(var.ipa_repo)}"
    ipa_version = "${jsonencode(var.ipa_version)}"
    ipa_smoketest_values = "${jsonencode(var.ipa_smoketest_values)}"
    ipa_smoketest_repo = "${jsonencode(var.ipa_smoketest_repo)}"
    ipa_smoketest_version = "${jsonencode(var.ipa_smoketest_version)}"
    ipa_smoketest_enabled = "${jsonencode(var.ipa_smoketest_enabled)}"
    monitoring_version = "${jsonencode(var.monitoring_version)}"
    ipa_pre_reqs_version = "${jsonencode(var.ipa_pre_reqs_version)}"
    ipa_crds_version = "${jsonencode(var.ipa_crds_version)}"
    ipa_enabled = "${jsonencode(var.ipa_enabled)}"
    ipa_values = "${jsonencode(var.ipa_values)}"
    vault_address = "${jsonencode(var.vault_address)}"
    vault_username = "${jsonencode(var.vault_username)}"
    sqs_sns = "${jsonencode(var.sqs_sns)}"
    restore_snapshot_enabled = "${jsonencode(var.restore_snapshot_enabled)}"
    restore_snapshot_name = "${jsonencode(var.restore_snapshot_name)}"
    oidc_enabled = "${jsonencode(var.oidc_enabled)}"
    oidc_client_id = "${jsonencode(var.oidc_client_id)}"
    oidc_config_name = "${jsonencode(var.oidc_config_name)}"
    oidc_issuer_url = "${jsonencode(var.oidc_issuer_url)}"
    oidc_groups_prefix = "${jsonencode(var.oidc_groups_prefix)}"
    oidc_groups_claim = "${jsonencode(var.oidc_groups_claim)}"
    oidc_username_prefix = "${jsonencode(var.oidc_username_prefix)}"
    oidc_username_claim = "${jsonencode(var.oidc_username_claim)}"
    monitoring_enabled = "${jsonencode(var.monitoring_enabled)}"
    hibernation_enabled = "${jsonencode(var.hibernation_enabled)}"
    keda_version = "${jsonencode(var.keda_version)}"
    external_secrets_version = "${jsonencode(var.external_secrets_version)}"
    opentelemetry_collector_version = "${jsonencode(var.opentelemetry_collector_version)}"
    nfs_subdir_external_provisioner_version = "${jsonencode(var.nfs_subdir_external_provisioner_version)}"
    include_fsx = "${jsonencode(var.include_fsx)}"
    include_pgbackup = "${jsonencode(var.include_pgbackup)}"
    include_efs = "${jsonencode(var.include_efs)}"
    performance_bucket = "${jsonencode(var.performance_bucket)}"
    crds_values_yaml_b64 = "${jsonencode(var.crds-values-yaml-b64)}"
    pre_reqs_values_yaml_b64 = "${jsonencode(var.pre-reqs-values-yaml-b64)}"
    enable_k8s_dashboard = "${jsonencode(var.enable_k8s_dashboard)}"
    use_acm = "${jsonencode(var.use_acm)}"
    acm_arn = "${jsonencode(var.acm_arn)}"
    enable_waf = "${jsonencode(var.enable_waf)}"
    vault_mount_path = "${jsonencode(var.vault_mount_path)}"
    terraform_vault_mount_path = "${jsonencode(var.terraform_vault_mount_path)}"
    enable_weather_station = "${jsonencode(var.enable_weather_station)}"
    aws_primary_dns_role_arn = "${jsonencode(var.aws_primary_dns_role_arn)}"
    is_alternate_account_domain = "${jsonencode(var.is_alternate_account_domain)}"
    domain_suffix = "${jsonencode(var.domain_suffix)}"
    domain_host = "${jsonencode(var.domain_host)}"
    alerting_enabled = "${jsonencode(var.alerting_enabled)}"
    alerting_slack_enabled = "${jsonencode(var.alerting_slack_enabled)}"
    alerting_pagerduty_enabled = "${jsonencode(var.alerting_pagerduty_enabled)}"
    alerting_email_enabled = "${jsonencode(var.alerting_email_enabled)}"
    alerting_slack_token = "${jsonencode(var.alerting_slack_token)}"
    alerting_slack_channel = "${jsonencode(var.alerting_slack_channel)}"
    alerting_pagerduty_integration_key = "${jsonencode(var.alerting_pagerduty_integration_key)}"
    alerting_email_from = "${jsonencode(var.alerting_email_from)}"
    alerting_email_to = "${jsonencode(var.alerting_email_to)}"
    alerting_email_host = "${jsonencode(var.alerting_email_host)}"
    alerting_email_username = "${jsonencode(var.alerting_email_username)}"
    alerting_email_password = "${jsonencode(var.alerting_email_password)}"
    eks_addon_version_guardduty = "${jsonencode(var.eks_addon_version_guardduty)}"
    use_static_ssl_certificates = "${jsonencode(var.use_static_ssl_certificates)}"
    ssl_static_secret_name = "${jsonencode(var.ssl_static_secret_name)}"
    local_registry_version = "${jsonencode(var.local_registry_version)}"
    local_registry_enabled = "${jsonencode(var.local_registry_enabled)}"
    devops_tools_cluster_host = "${jsonencode(var.devops_tools_cluster_host)}"
    thanos_grafana_admin_username = "${jsonencode(var.thanos_grafana_admin_username)}"
    thanos_cluster_host = "${jsonencode(var.thanos_cluster_host)}"
    thanos_cluster_name = "${jsonencode(var.thanos_cluster_name)}"
    indico_devops_aws_region = "${jsonencode(var.indico_devops_aws_region)}"
    thanos_enabled = "${jsonencode(var.thanos_enabled)}"
    keycloak_enabled = "${jsonencode(var.keycloak_enabled)}"
    terraform_smoketests_enabled = "${jsonencode(var.terraform_smoketests_enabled)}"
    on_prem_test = "${jsonencode(var.on_prem_test)}"
    harness_delegate = "${jsonencode(var.harness_delegate)}"
    harness_delegate_replicas = "${jsonencode(var.harness_delegate_replicas)}"
    harness_mount_path = "${jsonencode(var.harness_mount_path)}"
    lambda_sns_forwarder_enabled = "${jsonencode(var.lambda_sns_forwarder_enabled)}"
    lambda_sns_forwarder_destination_endpoint = "${jsonencode(var.lambda_sns_forwarder_destination_endpoint)}"
    lambda_sns_forwarder_topic_arn = "${jsonencode(var.lambda_sns_forwarder_topic_arn)}"
    lambda_sns_forwarder_github_organization = "${jsonencode(var.lambda_sns_forwarder_github_organization)}"
    lambda_sns_forwarder_github_repository = "${jsonencode(var.lambda_sns_forwarder_github_repository)}"
    lambda_sns_forwarder_github_branch = "${jsonencode(var.lambda_sns_forwarder_github_branch)}"
    lambda_sns_forwarder_github_zip_path = "${jsonencode(var.lambda_sns_forwarder_github_zip_path)}"
    lambda_sns_forwarder_function_variables = "${jsonencode(var.lambda_sns_forwarder_function_variables)}"
    enable_s3_backup = "${jsonencode(var.enable_s3_backup)}"
    cluster_api_endpoint_public = "${jsonencode(var.cluster_api_endpoint_public)}"
    network_allow_public = "${jsonencode(var.network_allow_public)}"
    internal_elb_use_public_subnets = "${jsonencode(var.internal_elb_use_public_subnets)}"
    network_module = "${jsonencode(var.network_module)}"
    network_type = "${jsonencode(var.network_type)}"
    load_vpc_id = "${jsonencode(var.load_vpc_id)}"
    private_subnet_tag_name = "${jsonencode(var.private_subnet_tag_name)}"
    private_subnet_tag_value = "${jsonencode(var.private_subnet_tag_value)}"
    public_subnet_tag_name = "${jsonencode(var.public_subnet_tag_name)}"
    public_subnet_tag_value = "${jsonencode(var.public_subnet_tag_value)}"
    sg_tag_name = "${jsonencode(var.sg_tag_name)}"
    sg_tag_value = "${jsonencode(var.sg_tag_value)}"
    s3_endpoint_enabled = "${jsonencode(var.s3_endpoint_enabled)}"
    image_registry = "${jsonencode(var.image_registry)}"
    secrets_operator_enabled = "${jsonencode(var.secrets_operator_enabled)}"
    vault_secrets_operator_version = "${jsonencode(var.vault_secrets_operator_version)}"
    firewall_subnet_cidrs = "${jsonencode(var.firewall_subnet_cidrs)}"
    enable_firewall = "${jsonencode(var.enable_firewall)}"
    firewall_allow_list = "${jsonencode(var.firewall_allow_list)}"
    dns_zone_name = "${jsonencode(var.dns_zone_name)}"
    readapi_customer = "${jsonencode(var.readapi_customer)}"
    create_guardduty_vpc_endpoint = "${jsonencode(var.create_guardduty_vpc_endpoint)}"
    use_nlb = "${jsonencode(var.use_nlb)}"
    enable_s3_access_logging = "${jsonencode(var.enable_s3_access_logging)}"
    enable_vpc_flow_logs = "${jsonencode(var.enable_vpc_flow_logs)}"
    vpc_flow_logs_iam_role_arn = "${jsonencode(var.vpc_flow_logs_iam_role_arn)}"
    instance_volume_size = "${jsonencode(var.instance_volume_size)}"
    instance_volume_type = "${jsonencode(var.instance_volume_type)}"

    }
  }
  