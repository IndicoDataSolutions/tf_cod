resource "kubernetes_config_map" "terraform-variables" {
  # this file is generated via pre-commit, DO NOT EDIT !
    depends_on = [null_resource.wait-for-tf-cod-chart-build]
    metadata {
      name = "terraform-variables"
    }
    data = {
      do_create_cluster = "${jsonencode(var.do_create_cluster)}"
    is_azure = "${jsonencode(var.is_azure)}"
    is_aws = "${jsonencode(var.is_aws)}"
    environment = "${jsonencode(var.environment)}"
    common_resource_group = "${jsonencode(var.common_resource_group)}"
    domain_suffix = "${jsonencode(var.domain_suffix)}"
    label = "${jsonencode(var.label)}"
    message = "${jsonencode(var.message)}"
    account = "${jsonencode(var.account)}"
    region = "${jsonencode(var.region)}"
    vnet_cidr = "${jsonencode(var.vnet_cidr)}"
    subnet_cidrs = "${jsonencode(var.subnet_cidrs)}"
    worker_subnet_cidrs = "${jsonencode(var.worker_subnet_cidrs)}"
    storage_account_name = "${jsonencode(var.storage_account_name)}"
    vault_address = "${jsonencode(var.vault_address)}"
    argo_enabled = "${jsonencode(var.argo_enabled)}"
    argo_host = "${jsonencode(var.argo_host)}"
    argo_namespace = "${jsonencode(var.argo_namespace)}"
    argo_repo = "${jsonencode(var.argo_repo)}"
    argo_branch = "${jsonencode(var.argo_branch)}"
    argo_path = "${jsonencode(var.argo_path)}"
    argo_github_team_owner = "${jsonencode(var.argo_github_team_owner)}"
    ipa_repo = "${jsonencode(var.ipa_repo)}"
    ipa_version = "${jsonencode(var.ipa_version)}"
    monitoring_version = "${jsonencode(var.monitoring_version)}"
    ipa_pre_reqs_version = "${jsonencode(var.ipa_pre_reqs_version)}"
    ipa_crds_version = "${jsonencode(var.ipa_crds_version)}"
    ipa_enabled = "${jsonencode(var.ipa_enabled)}"
    ipa_values = "${jsonencode(var.ipa_values)}"
    crds_values_yaml_b64 = "${jsonencode(var.crds-values-yaml-b64)}"
    pre_reqs_values_yaml_b64 = "${jsonencode(var.pre-reqs-values-yaml-b64)}"
    private_cluster_enabled = "${jsonencode(var.private_cluster_enabled)}"
    svp_client_id = "${jsonencode(var.svp_client_id)}"
    svp_client_secret = "${jsonencode(var.svp_client_secret)}"
    k8s_version = "${jsonencode(var.k8s_version)}"
    default_node_pool = "${jsonencode(var.default_node_pool)}"
    additional_node_pools = "${jsonencode(var.additional_node_pools)}"
    applications = "${jsonencode(var.applications)}"
    restore_snapshot_enabled = "${jsonencode(var.restore_snapshot_enabled)}"
    restore_snapshot_name = "${jsonencode(var.restore_snapshot_name)}"
    monitoring_enabled = "${jsonencode(var.monitoring_enabled)}"
    keda_version = "${jsonencode(var.keda_version)}"
    external_secrets_version = "${jsonencode(var.external_secrets_version)}"
    opentelemetry_collector_version = "${jsonencode(var.opentelemetry-collector_version)}"
    ipa_smoketest_values = "${jsonencode(var.ipa_smoketest_values)}"
    ipa_smoketest_repo = "${jsonencode(var.ipa_smoketest_repo)}"
    ipa_smoketest_version = "${jsonencode(var.ipa_smoketest_version)}"
    ipa_smoketest_slack_channel = "${jsonencode(var.ipa_smoketest_slack_channel)}"
    ipa_smoketest_enabled = "${jsonencode(var.ipa_smoketest_enabled)}"
    admin_group_name = "${jsonencode(var.admin_group_name)}"
    enable_k8s_dashboard = "${jsonencode(var.enable_k8s_dashboard)}"
    snapshots_resource_group_name = "${jsonencode(var.snapshots_resource_group_name)}"
    name = "${jsonencode(var.name)}"
    cod_snapshot_restore_version = "${jsonencode(var.cod_snapshot_restore_version)}"
    vault_mount_path = "${jsonencode(var.vault_mount_path)}"
    vault_username = "${jsonencode(var.vault_username)}"
    github_organization = "${jsonencode(var.github_organization)}"
    ad_group_name = "${jsonencode(var.ad_group_name)}"
    enable_ad_group_mapping = "${jsonencode(var.enable_ad_group_mapping)}"
    enable_readapi = "${jsonencode(var.enable_readapi)}"
    azure_readapi_client_id = "${jsonencode(var.azure_readapi_client_id)}"
    azure_readapi_subscription_id = "${jsonencode(var.azure_readapi_subscription_id)}"
    azure_readapi_tenant_id = "${jsonencode(var.azure_readapi_tenant_id)}"
    azure_indico_io_client_id = "${jsonencode(var.azure_indico_io_client_id)}"
    azure_indico_io_subscription_id = "${jsonencode(var.azure_indico_io_subscription_id)}"
    azure_indico_io_tenant_id = "${jsonencode(var.azure_indico_io_tenant_id)}"
    is_openshift = "${jsonencode(var.is_openshift)}"
    include_external_dns = "${jsonencode(var.include_external_dns)}"
    use_workload_identity = "${jsonencode(var.use_workload_identity)}"
    openshift_pull_secret = "${jsonencode(var.openshift_pull_secret)}"
    servicebus_pricing_tier = "${jsonencode(var.servicebus_pricing_tier)}"
    servicebus_message_filter = "${jsonencode(var.servicebus_message_filter)}"
    enable_servicebus = "${jsonencode(var.enable_servicebus)}"
    is_alternate_account_domain = "${jsonencode(var.is_alternate_account_domain)}"
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
    monitor_retention_in_days = "${jsonencode(var.monitor_retention_in_days)}"
    local_registry_version = "${jsonencode(var.local_registry_version)}"
    local_registry_enabled = "${jsonencode(var.local_registry_enabled)}"
    devops_tools_cluster_host = "${jsonencode(var.devops_tools_cluster_host)}"
    thanos_grafana_admin_username = "${jsonencode(var.thanos_grafana_admin_username)}"
    thanos_cluster_host = "${jsonencode(var.thanos_cluster_host)}"
    indico_devops_aws_region = "${jsonencode(var.indico_devops_aws_region)}"
    thanos_cluster_name = "${jsonencode(var.thanos_cluster_name)}"
    thanos_enabled = "${jsonencode(var.thanos_enabled)}"
    harness_delegate = "${jsonencode(var.harness_delegate)}"
    harness_mount_path = "${jsonencode(var.harness_mount_path)}"
    terraform_smoketests_enabled = "${jsonencode(var.terraform_smoketests_enabled)}"
    resource_group_name = "${jsonencode(var.resource_group_name)}"
    create_resource_group = "${jsonencode(var.create_resource_group)}"
    use_static_ssl_certificates = "${jsonencode(var.use_static_ssl_certificates)}"
    ssl_static_secret_name = "${jsonencode(var.ssl_static_secret_name)}"
    sentinel_workspace_name = "${jsonencode(var.sentinel_workspace_name)}"
    sentinel_workspace_resource_group_name = "${jsonencode(var.sentinel_workspace_resource_group_name)}"
    sentinel_workspace_id = "${jsonencode(var.sentinel_workspace_id)}"
    cluster_manager_vm_size = "${jsonencode(var.cluster_manager_vm_size)}"
    network_type = "${jsonencode(var.network_type)}"
    network_resource_group_name = "${jsonencode(var.network_resource_group_name)}"
    virtual_network_name = "${jsonencode(var.virtual_network_name)}"
    virtual_subnet_name = "${jsonencode(var.virtual_subnet_name)}"
    keyvault_name = "${jsonencode(var.keyvault_name)}"
    network_plugin = "${jsonencode(var.network_plugin)}"
    network_plugin_mode = "${jsonencode(var.network_plugin_mode)}"
    enable_custom_cluster_issuer = "${jsonencode(var.enable_custom_cluster_issuer)}"
    custom_cluster_issuer_spec = "${jsonencode(var.custom_cluster_issuer_spec)}"

    }
  }
  