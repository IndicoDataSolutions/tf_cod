resource "kubernetes_config_map" "terraform-variables" {
  metadata {
    name = "terraform-variables"
  }
  data = {
    is_azure = "${var.is_azure}"
    is_aws = "${var.is_aws}"
    label = "${var.label}"
    message = "${var.message}"
    harbor_pull_secret_b64 = "${var.harbor_pull_secret_b64}"
    applications = "${var.applications}"
    region = "${var.region}"
    aws_access_key = "${var.aws_access_key}"
    aws_secret_key = "${var.aws_secret_key}"
    direct_connect = "${var.direct_connect}"
    additional_tags = "${var.additional_tags}"
    default_tags = "${var.default_tags}"
    vpc_cidr = "${var.vpc_cidr}"
    public_ip = "${var.public_ip}"
    vpc_name = "${var.vpc_name}"
    private_subnet_cidrs = "${var.private_subnet_cidrs}"
    public_subnet_cidrs = "${var.public_subnet_cidrs}"
    subnet_az_zones = "${var.subnet_az_zones}"
    storage_gateway_size = "${var.storage_gateway_size}"
    existing_kms_key = "${var.existing_kms_key}"
    bucket_versioning = "${var.bucket_versioning}"
    submission_expiry = "${var.submission_expiry}"
    uploads_expiry = "${var.uploads_expiry}"
    name = "${var.name}"
    cluster_name = "${var.cluster_name}"
    k8s_version = "${var.k8s_version}"
    node_groups = "${var.node_groups}"
    node_bootstrap_arguments = "${var.node_bootstrap_arguments}"
    node_user_data = "${var.node_user_data}"
    node_disk_size = "${var.node_disk_size}"
    cluster_node_policies = "${var.cluster_node_policies}"
    kms_encrypt_secrets = "${var.kms_encrypt_secrets}"
    enable_readapi = "${var.enable_readapi}"
    azure_indico_io_client_id = "${var.azure_indico_io_client_id}"
    azure_indico_io_client_secret = "${var.azure_indico_io_client_secret}"
    azure_indico_io_subscription_id = "${var.azure_indico_io_subscription_id}"
    azure_indico_io_tenant_id = "${var.azure_indico_io_tenant_id}"
    eks_cluster_iam_role = "${var.eks_cluster_iam_role}"
    eks_cluster_nodes_iam_role = "${var.eks_cluster_nodes_iam_role}"
    storage_capacity = "${var.storage_capacity}"
    deletion_protection_enabled = "${var.deletion_protection_enabled}"
    skip_final_snapshot = "${var.skip_final_snapshot}"
    per_unit_storage_throughput = "${var.per_unit_storage_throughput}"
    az_count = "${var.az_count}"
    snapshot_id = "${var.snapshot_id}"
    include_rox = "${var.include_rox}"
    aws_account = "${var.aws_account}"
    argo_host = "${var.argo_host}"
    argo_username = "${var.argo_username}"
    argo_password = "${var.argo_password}"
    argo_repo = "${var.argo_repo}"
    argo_branch = "${var.argo_branch}"
    argo_namespace = "${var.argo_namespace}"
    argo_path = "${var.argo_path}"
    argo_github_team_owner = "${var.argo_github_team_owner}"
    ipa_repo = "${var.ipa_repo}"
    ipa_version = "${var.ipa_version}"
    ipa_smoketest_values = "${var.ipa_smoketest_values}"
    ipa_smoketest_repo = "${var.ipa_smoketest_repo}"
    ipa_smoketest_version = "${var.ipa_smoketest_version}"
    ipa_smoketest_enabled = "${var.ipa_smoketest_enabled}"
    monitoring_version = "${var.monitoring_version}"
    ipa_pre_reqs_version = "${var.ipa_pre_reqs_version}"
    ipa_crds_version = "${var.ipa_crds_version}"
    ipa_enabled = "${var.ipa_enabled}"
    ipa_values = "${var.ipa_values}"
    git_pat = "${var.git_pat}"
    vault_address = "${var.vault_address}"
    vault_username = "${var.vault_username}"
    vault_password = "${var.vault_password}"
    sqs_sns = "${var.sqs_sns}"
    restore_snapshot_enabled = "${var.restore_snapshot_enabled}"
    restore_snapshot_name = "${var.restore_snapshot_name}"
    oidc_enabled = "${var.oidc_enabled}"
    oidc_client_id = "${var.oidc_client_id}"
    oidc_config_name = "${var.oidc_config_name}"
    oidc_issuer_url = "${var.oidc_issuer_url}"
    oidc_groups_prefix = "${var.oidc_groups_prefix}"
    oidc_groups_claim = "${var.oidc_groups_claim}"
    oidc_username_prefix = "${var.oidc_username_prefix}"
    oidc_username_claim = "${var.oidc_username_claim}"
    monitoring_enabled = "${var.monitoring_enabled}"
    hibernation_enabled = "${var.hibernation_enabled}"
    keda_version = "${var.keda_version}"
    opentelemetry-collector_version = "${var.opentelemetry-collector_version}"
    include_fsx = "${var.include_fsx}"
    include_pgbackup = "${var.include_pgbackup}"
    include_efs = "${var.include_efs}"
    performance_bucket = "${var.performance_bucket}"
    crds-values-yaml-b64 = "${var.crds-values-yaml-b64}"
    pre-reqs-values-yaml-b64 = "${var.pre-reqs-values-yaml-b64}"
    k8s_dashboard_chart_version = "${var.k8s_dashboard_chart_version}"
    enable_k8s_dashboard = "${var.enable_k8s_dashboard}"
    use_acm = "${var.use_acm}"
    terraform_vault_mount_path = "${var.terraform_vault_mount_path}"
    snowflake_region = "${var.snowflake_region}"
    snowflake_username = "${var.snowflake_username}"
    snowflake_account = "${var.snowflake_account}"
    snowflake_private_key = "${var.snowflake_private_key}"
    snowflake_db_name = "${var.snowflake_db_name}"
    enable_weather_station = "${var.enable_weather_station}"
    aws_primary_dns_role_arn = "${var.aws_primary_dns_role_arn}"
    is_alternate_account_domain = "${var.is_alternate_account_domain}"
    domain_host = "${var.domain_host}"
    alerting_enabled = "${var.alerting_enabled}"
    alerting_slack_enabled = "${var.alerting_slack_enabled}"
    alerting_pagerduty_enabled = "${var.alerting_pagerduty_enabled}"
    alerting_email_enabled = "${var.alerting_email_enabled}"
    alerting_slack_token = "${var.alerting_slack_token}"
    alerting_slack_channel = "${var.alerting_slack_channel}"
    alerting_pagerduty_integration_key = "${var.alerting_pagerduty_integration_key}"
    alerting_email_from = "${var.alerting_email_from}"
    alerting_email_to = "${var.alerting_email_to}"
    alerting_email_host = "${var.alerting_email_host}"
    alerting_email_username = "${var.alerting_email_username}"
    alerting_email_password = "${var.alerting_email_password}"
    eks_addon_version_guardduty = "${var.eks_addon_version_guardduty}"
    use_static_ssl_certificates = "${var.use_static_ssl_certificates}"
    ssl_static_secret_name = "${var.ssl_static_secret_name}"
  }
}
