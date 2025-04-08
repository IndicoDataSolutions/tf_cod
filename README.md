## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.5 |
| <a name="requirement_argocd"></a> [argocd](#requirement\_argocd) | 6.0.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.68.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | 5.34.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.15.0 |
| <a name="requirement_htpasswd"></a> [htpasswd](#requirement\_htpasswd) | 1.0.4 |
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | 4.3.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | 1.14.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.33.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~>3.5.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.9.1 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | 3.22.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_argocd"></a> [argocd](#provider\_argocd) | 6.0.2 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.68.0 |
| <a name="provider_aws.aws-indico-devops"></a> [aws.aws-indico-devops](#provider\_aws.aws-indico-devops) | 5.68.0 |
| <a name="provider_aws.dns-control"></a> [aws.dns-control](#provider\_aws.dns-control) | 5.68.0 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.4 |
| <a name="provider_github"></a> [github](#provider\_github) | 5.34.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.16.1 |
| <a name="provider_htpasswd"></a> [htpasswd](#provider\_htpasswd) | 1.0.4 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.14.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.33.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.2 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.3 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.5.1 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.9.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.6 |
| <a name="provider_vault"></a> [vault](#provider\_vault) | 3.22.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_argo-registration"></a> [argo-registration](#module\_argo-registration) | app.terraform.io/indico/indico-argo-registration/mod | 1.2.2 |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | app.terraform.io/indico/indico-aws-eks-cluster/mod | 8.2.3 |
| <a name="module_efs-storage"></a> [efs-storage](#module\_efs-storage) | app.terraform.io/indico/indico-aws-efs/mod | 2.0.0 |
| <a name="module_efs-storage-local-registry"></a> [efs-storage-local-registry](#module\_efs-storage-local-registry) | app.terraform.io/indico/indico-aws-efs/mod | 0.0.1 |
| <a name="module_fsx-storage"></a> [fsx-storage](#module\_fsx-storage) | app.terraform.io/indico/indico-aws-fsx/mod | 2.0.0 |
| <a name="module_harness_delegate"></a> [harness\_delegate](#module\_harness\_delegate) | ./modules/harness | n/a |
| <a name="module_k8s_dashboard"></a> [k8s\_dashboard](#module\_k8s\_dashboard) | ./modules/aws/k8s_dashboard | n/a |
| <a name="module_keycloak"></a> [keycloak](#module\_keycloak) | ./modules/aws/keycloak | n/a |
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | app.terraform.io/indico/indico-aws-kms/mod | 2.1.2 |
| <a name="module_lambda-sns-forwarder"></a> [lambda-sns-forwarder](#module\_lambda-sns-forwarder) | app.terraform.io/indico/indico-lambda-sns-forwarder/mod | 2.0.0 |
| <a name="module_networking"></a> [networking](#module\_networking) | app.terraform.io/indico/indico-aws-network/mod | 2.1.0 |
| <a name="module_public_networking"></a> [public\_networking](#module\_public\_networking) | app.terraform.io/indico/indico-aws-network/mod | 1.2.2 |
| <a name="module_s3-storage"></a> [s3-storage](#module\_s3-storage) | app.terraform.io/indico/indico-aws-buckets/mod | 3.3.1 |
| <a name="module_secrets-operator-setup"></a> [secrets-operator-setup](#module\_secrets-operator-setup) | ./modules/common/vault-secrets-operator-setup | n/a |
| <a name="module_security-group"></a> [security-group](#module\_security-group) | app.terraform.io/indico/indico-aws-security-group/mod | 3.0.0 |
| <a name="module_sqs_sns"></a> [sqs\_sns](#module\_sqs\_sns) | app.terraform.io/indico/indico-aws-sqs-sns/mod | 1.2.0 |

## Resources

| Name | Type |
|------|------|
| [argocd_application.ipa](https://registry.terraform.io/providers/oboukili/argocd/6.0.2/docs/resources/application) | resource |
| [aws_acm_certificate.alb](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.alb](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/acm_certificate_validation) | resource |
| [aws_efs_access_point.local-registry](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/efs_access_point) | resource |
| [aws_eks_addon.guardduty](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/eks_addon) | resource |
| [aws_key_pair.kp](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/key_pair) | resource |
| [aws_route53_record.alb](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/route53_record) | resource |
| [aws_route53_record.alertmanager-caa](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/route53_record) | resource |
| [aws_route53_record.grafana-caa](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/route53_record) | resource |
| [aws_route53_record.ipa-app-caa](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/route53_record) | resource |
| [aws_route53_record.prometheus-caa](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/route53_record) | resource |
| [aws_security_group.eks_vpc_endpoint_guardduty](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.eks_vpc_guardduty](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/vpc_endpoint) | resource |
| [aws_wafv2_web_acl.wafv2-acl](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/resources/wafv2_web_acl) | resource |
| [github_repository_file.alb-values-yaml](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/resources/repository_file) | resource |
| [github_repository_file.argocd-application-yaml](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/resources/repository_file) | resource |
| [github_repository_file.crds-values-yaml](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/resources/repository_file) | resource |
| [github_repository_file.custom-application-yaml](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/resources/repository_file) | resource |
| [github_repository_file.pre-reqs-values-yaml](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/resources/repository_file) | resource |
| [github_repository_file.smoketest-application-yaml](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/resources/repository_file) | resource |
| [helm_release.external-secrets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.ipa-crds](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.ipa-pre-requisites](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.ipa-vso](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.keda-monitoring](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.local-registry](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.monitoring](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.nfs-provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.opentelemetry-collector](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.terraform-smoketests](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [htpasswd_password.hash](https://registry.terraform.io/providers/loafoe/htpasswd/1.0.4/docs/resources/password) | resource |
| [kubectl_manifest.gp2-storageclass](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubectl_manifest.nfs_server](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubectl_manifest.nfs_server_service](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubectl_manifest.nfs_volume](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubectl_manifest.snapshot-cluster-role](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubectl_manifest.snapshot-cluster-role-binding](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubectl_manifest.snapshot-service-account](https://registry.terraform.io/providers/gavinbunney/kubectl/1.14.0/docs/resources/manifest) | resource |
| [kubernetes_cluster_role_binding.cod-role-bindings](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.devops-rbac-bindings](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_cluster_role_binding.eng-qa-rbac-bindings](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_config_map.terraform-variables](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_job.snapshot-restore-job](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/job) | resource |
| [kubernetes_namespace.local-registry](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_persistent_volume.local-registry](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume) | resource |
| [kubernetes_persistent_volume_claim.local-registry](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume_claim) | resource |
| [kubernetes_secret.harbor-pull-secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.issuer-secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.readapi](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_storage_class_v1.local-registry](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class_v1) | resource |
| [null_resource.enable-oidc](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.get_nfs_server_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.s3-delete-data-bucket](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.s3-delete-data-pgbackup-bucket](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.update_storage_class](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait-for-tf-cod-chart-build](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_password.monitoring-password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.salt](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.wait_1_minutes_after_crds](https://registry.terraform.io/providers/hashicorp/time/0.9.1/docs/resources/sleep) | resource |
| [time_sleep.wait_1_minutes_after_pre_reqs](https://registry.terraform.io/providers/hashicorp/time/0.9.1/docs/resources/sleep) | resource |
| [tls_private_key.pk](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.local](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster.thanos](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.local](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/eks_cluster_auth) | data source |
| [aws_eks_cluster_auth.thanos](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.eks_vpc_guardduty](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.primary](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/route53_zone) | data source |
| [aws_vpc_endpoint_service.guardduty](https://registry.terraform.io/providers/hashicorp/aws/5.68.0/docs/data-sources/vpc_endpoint_service) | data source |
| [external_external.git_information](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [github_repository.argo-github-repo](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/data-sources/repository) | data source |
| [github_repository_file.data-crds-values](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/data-sources/repository_file) | data source |
| [github_repository_file.data-pre-reqs-values](https://registry.terraform.io/providers/integrations/github/5.34.0/docs/data-sources/repository_file) | data source |
| [local_file.nfs_ip](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [vault_kv_secret_v2.account-robot-credentials](https://registry.terraform.io/providers/hashicorp/vault/3.22.0/docs/data-sources/kv_secret_v2) | data source |
| [vault_kv_secret_v2.delegate_secrets](https://registry.terraform.io/providers/hashicorp/vault/3.22.0/docs/data-sources/kv_secret_v2) | data source |
| [vault_kv_secret_v2.harbor-api-token](https://registry.terraform.io/providers/hashicorp/vault/3.22.0/docs/data-sources/kv_secret_v2) | data source |
| [vault_kv_secret_v2.readapi_secret](https://registry.terraform.io/providers/hashicorp/vault/3.22.0/docs/data-sources/kv_secret_v2) | data source |
| [vault_kv_secret_v2.zerossl_data](https://registry.terraform.io/providers/hashicorp/vault/3.22.0/docs/data-sources/kv_secret_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_arn"></a> [acm\_arn](#input\_acm\_arn) | arn of a pre-existing acm certificate | `string` | `""` | no |
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additonal tags to add to each resource | `map(string)` | `null` | no |
| <a name="input_alerting_email_enabled"></a> [alerting\_email\_enabled](#input\_alerting\_email\_enabled) | enable alerts via email | `bool` | `false` | no |
| <a name="input_alerting_email_from"></a> [alerting\_email\_from](#input\_alerting\_email\_from) | alerting\_email\_from. | `string` | `"blank"` | no |
| <a name="input_alerting_email_host"></a> [alerting\_email\_host](#input\_alerting\_email\_host) | alerting\_email\_host | `string` | `"blank"` | no |
| <a name="input_alerting_email_password"></a> [alerting\_email\_password](#input\_alerting\_email\_password) | alerting\_email\_password | `string` | `"blank"` | no |
| <a name="input_alerting_email_to"></a> [alerting\_email\_to](#input\_alerting\_email\_to) | alerting\_email\_to | `string` | `"blank"` | no |
| <a name="input_alerting_email_username"></a> [alerting\_email\_username](#input\_alerting\_email\_username) | alerting\_email\_username | `string` | `"blank"` | no |
| <a name="input_alerting_enabled"></a> [alerting\_enabled](#input\_alerting\_enabled) | enable alerts | `bool` | `false` | no |
| <a name="input_alerting_pagerduty_enabled"></a> [alerting\_pagerduty\_enabled](#input\_alerting\_pagerduty\_enabled) | enable alerts via pagerduty | `bool` | `false` | no |
| <a name="input_alerting_pagerduty_integration_key"></a> [alerting\_pagerduty\_integration\_key](#input\_alerting\_pagerduty\_integration\_key) | Secret pagerduty\_integration\_key. | `string` | `"blank"` | no |
| <a name="input_alerting_slack_channel"></a> [alerting\_slack\_channel](#input\_alerting\_slack\_channel) | Slack channel for sending notifications from alertmanager. | `string` | `"blank"` | no |
| <a name="input_alerting_slack_enabled"></a> [alerting\_slack\_enabled](#input\_alerting\_slack\_enabled) | enable alerts via slack | `bool` | `false` | no |
| <a name="input_alerting_slack_token"></a> [alerting\_slack\_token](#input\_alerting\_slack\_token) | Secret url with embedded token needed for slack webhook delivery. | `string` | `"blank"` | no |
| <a name="input_applications"></a> [applications](#input\_applications) | n/a | <pre>map(object({<br>    name            = string<br>    repo            = string<br>    chart           = string<br>    version         = string<br>    values          = string,<br>    namespace       = string,<br>    createNamespace = bool,<br>    vaultPath       = string<br>  }))</pre> | `{}` | no |
| <a name="input_argo_branch"></a> [argo\_branch](#input\_argo\_branch) | Branch to use on argo\_repo | `string` | `""` | no |
| <a name="input_argo_enabled"></a> [argo\_enabled](#input\_argo\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_argo_github_team_owner"></a> [argo\_github\_team\_owner](#input\_argo\_github\_team\_owner) | The GitHub Team that has owner-level access to this Argo Project | `string` | `"devops-core-admins"` | no |
| <a name="input_argo_host"></a> [argo\_host](#input\_argo\_host) | n/a | `string` | `"argo.devops.indico.io"` | no |
| <a name="input_argo_namespace"></a> [argo\_namespace](#input\_argo\_namespace) | n/a | `string` | `"argo"` | no |
| <a name="input_argo_password"></a> [argo\_password](#input\_argo\_password) | n/a | `string` | `"not used"` | no |
| <a name="input_argo_path"></a> [argo\_path](#input\_argo\_path) | Path within the argo\_repo containing yaml | `string` | `"."` | no |
| <a name="input_argo_repo"></a> [argo\_repo](#input\_argo\_repo) | Argo Github Repository containing the IPA Application | `string` | `""` | no |
| <a name="input_argo_username"></a> [argo\_username](#input\_argo\_username) | n/a | `string` | `"admin"` | no |
| <a name="input_aws_access_key"></a> [aws\_access\_key](#input\_aws\_access\_key) | The AWS access key to use for deployment | `string` | n/a | yes |
| <a name="input_aws_account"></a> [aws\_account](#input\_aws\_account) | The Name of the AWS Acccount this cluster lives in | `string` | n/a | yes |
| <a name="input_aws_primary_dns_role_arn"></a> [aws\_primary\_dns\_role\_arn](#input\_aws\_primary\_dns\_role\_arn) | The AWS arn for the role needed to manage route53 DNS in a different account. | `string` | `""` | no |
| <a name="input_aws_secret_key"></a> [aws\_secret\_key](#input\_aws\_secret\_key) | The AWS secret key to use for deployment | `string` | n/a | yes |
| <a name="input_aws_session_token"></a> [aws\_session\_token](#input\_aws\_session\_token) | The AWS session token to use for deployment | `string` | `null` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of availability zones for nodes | `number` | `2` | no |
| <a name="input_azure_indico_io_client_id"></a> [azure\_indico\_io\_client\_id](#input\_azure\_indico\_io\_client\_id) | Old provider configuration to remove orphaned readapi resources | `string` | `""` | no |
| <a name="input_azure_indico_io_client_secret"></a> [azure\_indico\_io\_client\_secret](#input\_azure\_indico\_io\_client\_secret) | n/a | `string` | `""` | no |
| <a name="input_azure_indico_io_subscription_id"></a> [azure\_indico\_io\_subscription\_id](#input\_azure\_indico\_io\_subscription\_id) | n/a | `string` | `""` | no |
| <a name="input_azure_indico_io_tenant_id"></a> [azure\_indico\_io\_tenant\_id](#input\_azure\_indico\_io\_tenant\_id) | n/a | `string` | `""` | no |
| <a name="input_azure_readapi_client_id"></a> [azure\_readapi\_client\_id](#input\_azure\_readapi\_client\_id) | n/a | `string` | `""` | no |
| <a name="input_azure_readapi_client_secret"></a> [azure\_readapi\_client\_secret](#input\_azure\_readapi\_client\_secret) | n/a | `string` | `""` | no |
| <a name="input_azure_readapi_subscription_id"></a> [azure\_readapi\_subscription\_id](#input\_azure\_readapi\_subscription\_id) | n/a | `string` | `""` | no |
| <a name="input_azure_readapi_tenant_id"></a> [azure\_readapi\_tenant\_id](#input\_azure\_readapi\_tenant\_id) | n/a | `string` | `""` | no |
| <a name="input_bucket_versioning"></a> [bucket\_versioning](#input\_bucket\_versioning) | Enable bucket object versioning | `bool` | `true` | no |
| <a name="input_cluster_api_endpoint_public"></a> [cluster\_api\_endpoint\_public](#input\_cluster\_api\_endpoint\_public) | If enabled this allow public access to the cluster api endpoint. | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | `"indico-cluster"` | no |
| <a name="input_cluster_node_policies"></a> [cluster\_node\_policies](#input\_cluster\_node\_policies) | Additonal IAM policies to add to the cluster IAM role | `list(any)` | <pre>[<br>  "IAMReadOnlyAccess"<br>]</pre> | no |
| <a name="input_crds-values-yaml-b64"></a> [crds-values-yaml-b64](#input\_crds-values-yaml-b64) | n/a | `string` | `"Cg=="` | no |
| <a name="input_create_guardduty_vpc_endpoint"></a> [create\_guardduty\_vpc\_endpoint](#input\_create\_guardduty\_vpc\_endpoint) | If true this will create a vpc endpoint for guardduty. | `bool` | `true` | no |
| <a name="input_csi_driver_nfs_version"></a> [csi\_driver\_nfs\_version](#input\_csi\_driver\_nfs\_version) | Version of csi-driver-nfs helm chart | `string` | `"v4.0.9"` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Default tags to add to each resource | `map(string)` | `null` | no |
| <a name="input_deletion_protection_enabled"></a> [deletion\_protection\_enabled](#input\_deletion\_protection\_enabled) | Enable deletion protection if set to true | `bool` | `true` | no |
| <a name="input_devops_tools_cluster_ca_certificate"></a> [devops\_tools\_cluster\_ca\_certificate](#input\_devops\_tools\_cluster\_ca\_certificate) | n/a | `string` | `"provided from the varset devops-tools-cluster"` | no |
| <a name="input_devops_tools_cluster_host"></a> [devops\_tools\_cluster\_host](#input\_devops\_tools\_cluster\_host) | n/a | `string` | `"provided from the varset devops-tools-cluster"` | no |
| <a name="input_direct_connect"></a> [direct\_connect](#input\_direct\_connect) | Sets up the direct connect configuration if true; else use public subnets | `bool` | `false` | no |
| <a name="input_dns_zone_name"></a> [dns\_zone\_name](#input\_dns\_zone\_name) | Name of the dns zone used to control DNS | `string` | `""` | no |
| <a name="input_domain_host"></a> [domain\_host](#input\_domain\_host) | domain host name. | `string` | `""` | no |
| <a name="input_domain_suffix"></a> [domain\_suffix](#input\_domain\_suffix) | Domain suffix | `string` | `"indico.io"` | no |
| <a name="input_efs_filesystem_name"></a> [efs\_filesystem\_name](#input\_efs\_filesystem\_name) | The filesystem name of an existing efs instance | `string` | `""` | no |
| <a name="input_efs_type"></a> [efs\_type](#input\_efs\_type) | n/a | `string` | `"create"` | no |
| <a name="input_eks_addon_version_guardduty"></a> [eks\_addon\_version\_guardduty](#input\_eks\_addon\_version\_guardduty) | enable guardduty | `bool` | `true` | no |
| <a name="input_eks_cluster_iam_role"></a> [eks\_cluster\_iam\_role](#input\_eks\_cluster\_iam\_role) | Name of the IAM role to assign to the EKS cluster; will be created if not supplied | `string` | `null` | no |
| <a name="input_eks_cluster_nodes_iam_role"></a> [eks\_cluster\_nodes\_iam\_role](#input\_eks\_cluster\_nodes\_iam\_role) | Name of the IAM role to assign to the EKS cluster nodes; will be created if not supplied | `string` | `null` | no |
| <a name="input_enable_firewall"></a> [enable\_firewall](#input\_enable\_firewall) | If enabled this will create firewall and internet gateway | `bool` | `false` | no |
| <a name="input_enable_k8s_dashboard"></a> [enable\_k8s\_dashboard](#input\_enable\_k8s\_dashboard) | n/a | `bool` | `true` | no |
| <a name="input_enable_readapi"></a> [enable\_readapi](#input\_enable\_readapi) | ReadAPI stuff | `bool` | `true` | no |
| <a name="input_enable_s3_access_logging"></a> [enable\_s3\_access\_logging](#input\_enable\_s3\_access\_logging) | If true this will enable access logging on the s3 buckets | `bool` | `true` | no |
| <a name="input_enable_s3_backup"></a> [enable\_s3\_backup](#input\_enable\_s3\_backup) | Allow backing up data bucket on s3 | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | If enabled this will create flow logs for the VPC | `bool` | `true` | no |
| <a name="input_enable_waf"></a> [enable\_waf](#input\_enable\_waf) | enables aws alb controller for app-edge, also creates waf rules. | `bool` | `false` | no |
| <a name="input_enable_weather_station"></a> [enable\_weather\_station](#input\_enable\_weather\_station) | whether or not to enable the weather station internal metrics collection service | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment of the cluster, determines which account readapi to use, options production/development | `string` | `"development"` | no |
| <a name="input_existing_kms_key"></a> [existing\_kms\_key](#input\_existing\_kms\_key) | Name of kms key if it exists in the account (eg. 'alias/<name>') | `string` | `""` | no |
| <a name="input_external_secrets_version"></a> [external\_secrets\_version](#input\_external\_secrets\_version) | Version of external-secrets helm chart | `string` | `"0.10.5"` | no |
| <a name="input_firewall_allow_list"></a> [firewall\_allow\_list](#input\_firewall\_allow\_list) | n/a | `list(string)` | <pre>[<br>  ".cognitiveservices.azure.com"<br>]</pre> | no |
| <a name="input_firewall_subnet_cidrs"></a> [firewall\_subnet\_cidrs](#input\_firewall\_subnet\_cidrs) | CIDR ranges for the firewall subnets | `list(string)` | `[]` | no |
| <a name="input_fsx_deployment_type"></a> [fsx\_deployment\_type](#input\_fsx\_deployment\_type) | The deployment type to launch | `string` | `"PERSISTENT_1"` | no |
| <a name="input_fsx_rox_arn"></a> [fsx\_rox\_arn](#input\_fsx\_rox\_arn) | ARN of the ROX FSx Lustre file system | `string` | `null` | no |
| <a name="input_fsx_rox_id"></a> [fsx\_rox\_id](#input\_fsx\_rox\_id) | ID of the existing FSx Lustre file system for ROX | `string` | `null` | no |
| <a name="input_fsx_rwx_arn"></a> [fsx\_rwx\_arn](#input\_fsx\_rwx\_arn) | ARN of the RWX FSx Lustre file system | `string` | `null` | no |
| <a name="input_fsx_rwx_dns_name"></a> [fsx\_rwx\_dns\_name](#input\_fsx\_rwx\_dns\_name) | DNS name for the RWX FSx Lustre file system | `string` | `null` | no |
| <a name="input_fsx_rwx_id"></a> [fsx\_rwx\_id](#input\_fsx\_rwx\_id) | ID of the existing FSx Lustre file system for RWX | `string` | `null` | no |
| <a name="input_fsx_rwx_mount_name"></a> [fsx\_rwx\_mount\_name](#input\_fsx\_rwx\_mount\_name) | Mount name for the RWX FSx Lustre file system | `string` | `null` | no |
| <a name="input_fsx_rwx_security_group_ids"></a> [fsx\_rwx\_security\_group\_ids](#input\_fsx\_rwx\_security\_group\_ids) | Security group IDs for the RWX FSx Lustre file system | `list(string)` | `[]` | no |
| <a name="input_fsx_rwx_subnet_ids"></a> [fsx\_rwx\_subnet\_ids](#input\_fsx\_rwx\_subnet\_ids) | Subnet IDs for the RWX FSx Lustre file system | `list(string)` | `[]` | no |
| <a name="input_fsx_type"></a> [fsx\_type](#input\_fsx\_type) | n/a | `string` | `"create"` | no |
| <a name="input_git_pat"></a> [git\_pat](#input\_git\_pat) | n/a | `string` | `""` | no |
| <a name="input_harbor_pull_secret_b64"></a> [harbor\_pull\_secret\_b64](#input\_harbor\_pull\_secret\_b64) | Harbor pull secret from Vault | `string` | n/a | yes |
| <a name="input_harness_delegate"></a> [harness\_delegate](#input\_harness\_delegate) | n/a | `bool` | `false` | no |
| <a name="input_harness_delegate_replicas"></a> [harness\_delegate\_replicas](#input\_harness\_delegate\_replicas) | n/a | `number` | `1` | no |
| <a name="input_harness_mount_path"></a> [harness\_mount\_path](#input\_harness\_mount\_path) | n/a | `string` | `"harness"` | no |
| <a name="input_hibernation_enabled"></a> [hibernation\_enabled](#input\_hibernation\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | docker image registry to use for pulling images. | `string` | `"harbor.devops.indico.io"` | no |
| <a name="input_include_efs"></a> [include\_efs](#input\_include\_efs) | Create efs | `bool` | `true` | no |
| <a name="input_include_fsx"></a> [include\_fsx](#input\_include\_fsx) | Create a fsx file system(s) | `bool` | `false` | no |
| <a name="input_include_pgbackup"></a> [include\_pgbackup](#input\_include\_pgbackup) | Create a read only FSx file system | `bool` | `true` | no |
| <a name="input_include_rox"></a> [include\_rox](#input\_include\_rox) | Create a read only FSx file system | `bool` | `false` | no |
| <a name="input_indico_aws_access_key_id"></a> [indico\_aws\_access\_key\_id](#input\_indico\_aws\_access\_key\_id) | The AWS access key for controlling dns in an alternate account | `string` | `""` | no |
| <a name="input_indico_aws_secret_access_key"></a> [indico\_aws\_secret\_access\_key](#input\_indico\_aws\_secret\_access\_key) | The AWS secret key for controlling dns in an alternate account | `string` | `""` | no |
| <a name="input_indico_aws_session_token"></a> [indico\_aws\_session\_token](#input\_indico\_aws\_session\_token) | The AWS session token to use for deployment in an alternate account | `string` | `null` | no |
| <a name="input_indico_devops_aws_access_key_id"></a> [indico\_devops\_aws\_access\_key\_id](#input\_indico\_devops\_aws\_access\_key\_id) | The Indico-Devops account access key | `string` | `""` | no |
| <a name="input_indico_devops_aws_region"></a> [indico\_devops\_aws\_region](#input\_indico\_devops\_aws\_region) | The Indico-Devops devops cluster region | `string` | `""` | no |
| <a name="input_indico_devops_aws_secret_access_key"></a> [indico\_devops\_aws\_secret\_access\_key](#input\_indico\_devops\_aws\_secret\_access\_key) | The Indico-Devops account secret | `string` | `""` | no |
| <a name="input_indico_devops_aws_session_token"></a> [indico\_devops\_aws\_session\_token](#input\_indico\_devops\_aws\_session\_token) | Indico-Devops account AWS session token to use for deployment | `string` | `null` | no |
| <a name="input_instance_volume_size"></a> [instance\_volume\_size](#input\_instance\_volume\_size) | The size of EBS volume to attach to the cluster nodes | `number` | `60` | no |
| <a name="input_instance_volume_type"></a> [instance\_volume\_type](#input\_instance\_volume\_type) | The type of EBS volume to attach to the cluster nodes | `string` | `"gp2"` | no |
| <a name="input_internal_elb_use_public_subnets"></a> [internal\_elb\_use\_public\_subnets](#input\_internal\_elb\_use\_public\_subnets) | If enabled, this will use public subnets for the internal elb. Otherwise use the private subnets | `bool` | `true` | no |
| <a name="input_ipa_crds_version"></a> [ipa\_crds\_version](#input\_ipa\_crds\_version) | n/a | `string` | `"0.2.1"` | no |
| <a name="input_ipa_enabled"></a> [ipa\_enabled](#input\_ipa\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_ipa_pre_reqs_version"></a> [ipa\_pre\_reqs\_version](#input\_ipa\_pre\_reqs\_version) | n/a | `string` | `"0.4.0"` | no |
| <a name="input_ipa_repo"></a> [ipa\_repo](#input\_ipa\_repo) | n/a | `string` | `"https://harbor.devops.indico.io/chartrepo/indico-charts"` | no |
| <a name="input_ipa_smoketest_enabled"></a> [ipa\_smoketest\_enabled](#input\_ipa\_smoketest\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_ipa_smoketest_repo"></a> [ipa\_smoketest\_repo](#input\_ipa\_smoketest\_repo) | n/a | `string` | `"https://harbor.devops.indico.io/chartrepo/indico-charts"` | no |
| <a name="input_ipa_smoketest_values"></a> [ipa\_smoketest\_values](#input\_ipa\_smoketest\_values) | n/a | `string` | `"Cg=="` | no |
| <a name="input_ipa_smoketest_version"></a> [ipa\_smoketest\_version](#input\_ipa\_smoketest\_version) | n/a | `string` | `"0.1.8"` | no |
| <a name="input_ipa_values"></a> [ipa\_values](#input\_ipa\_values) | n/a | `string` | `""` | no |
| <a name="input_ipa_version"></a> [ipa\_version](#input\_ipa\_version) | n/a | `string` | `"0.12.1"` | no |
| <a name="input_is_alternate_account_domain"></a> [is\_alternate\_account\_domain](#input\_is\_alternate\_account\_domain) | domain name is controlled by a different aws account | `string` | `"false"` | no |
| <a name="input_is_aws"></a> [is\_aws](#input\_is\_aws) | n/a | `bool` | `true` | no |
| <a name="input_is_azure"></a> [is\_azure](#input\_is\_azure) | n/a | `bool` | `false` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | The EKS version to use | `string` | `"1.32"` | no |
| <a name="input_keda_version"></a> [keda\_version](#input\_keda\_version) | n/a | `string` | `"2.15.2"` | no |
| <a name="input_keycloak_enabled"></a> [keycloak\_enabled](#input\_keycloak\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_kms_encrypt_secrets"></a> [kms\_encrypt\_secrets](#input\_kms\_encrypt\_secrets) | Encrypt EKS secrets with KMS | `bool` | `true` | no |
| <a name="input_label"></a> [label](#input\_label) | The unique string to be prepended to resources names | `string` | `"indico"` | no |
| <a name="input_lambda_sns_forwarder_destination_endpoint"></a> [lambda\_sns\_forwarder\_destination\_endpoint](#input\_lambda\_sns\_forwarder\_destination\_endpoint) | destination URL for the lambda sns forwarder | `string` | `""` | no |
| <a name="input_lambda_sns_forwarder_enabled"></a> [lambda\_sns\_forwarder\_enabled](#input\_lambda\_sns\_forwarder\_enabled) | If enabled a lamda will be provisioned to forward sns messages to an external endpoint. | `bool` | `false` | no |
| <a name="input_lambda_sns_forwarder_function_variables"></a> [lambda\_sns\_forwarder\_function\_variables](#input\_lambda\_sns\_forwarder\_function\_variables) | A map of variables for the lambda\_sns\_forwarder code to use | `map(any)` | `{}` | no |
| <a name="input_lambda_sns_forwarder_github_branch"></a> [lambda\_sns\_forwarder\_github\_branch](#input\_lambda\_sns\_forwarder\_github\_branch) | The github branch / tag containing the lambda\_sns\_forwarder code to use | `string` | `"main"` | no |
| <a name="input_lambda_sns_forwarder_github_organization"></a> [lambda\_sns\_forwarder\_github\_organization](#input\_lambda\_sns\_forwarder\_github\_organization) | The github organization containing the lambda\_sns\_forwarder code to use | `string` | `"IndicoDataSolutions"` | no |
| <a name="input_lambda_sns_forwarder_github_repository"></a> [lambda\_sns\_forwarder\_github\_repository](#input\_lambda\_sns\_forwarder\_github\_repository) | The github repository containing the lambda\_sns\_forwarder code to use | `string` | `""` | no |
| <a name="input_lambda_sns_forwarder_github_zip_path"></a> [lambda\_sns\_forwarder\_github\_zip\_path](#input\_lambda\_sns\_forwarder\_github\_zip\_path) | Full path to the lambda zip file | `string` | `"zip/lambda.zip"` | no |
| <a name="input_lambda_sns_forwarder_topic_arn"></a> [lambda\_sns\_forwarder\_topic\_arn](#input\_lambda\_sns\_forwarder\_topic\_arn) | SNS topic to triger lambda forwarder. | `string` | `""` | no |
| <a name="input_load_vpc_id"></a> [load\_vpc\_id](#input\_load\_vpc\_id) | This is required if loading a network rather than creating one. | `string` | `""` | no |
| <a name="input_local_registry_enabled"></a> [local\_registry\_enabled](#input\_local\_registry\_enabled) | n/a | `bool` | `false` | no |
| <a name="input_local_registry_version"></a> [local\_registry\_version](#input\_local\_registry\_version) | n/a | `string` | `"unused"` | no |
| <a name="input_message"></a> [message](#input\_message) | The commit message for updates | `string` | `"Managed by Terraform"` | no |
| <a name="input_monitoring_enabled"></a> [monitoring\_enabled](#input\_monitoring\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_monitoring_version"></a> [monitoring\_version](#input\_monitoring\_version) | n/a | `string` | `"3.0.0"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name to use in all cluster resources names | `string` | `"indico"` | no |
| <a name="input_network_allow_public"></a> [network\_allow\_public](#input\_network\_allow\_public) | If enabled this will create public subnets, IGW, and NAT gateway. | `bool` | `true` | no |
| <a name="input_network_module"></a> [network\_module](#input\_network\_module) | n/a | `string` | `"networking"` | no |
| <a name="input_network_type"></a> [network\_type](#input\_network\_type) | n/a | `string` | `"create"` | no |
| <a name="input_nfs_subdir_external_provisioner_version"></a> [nfs\_subdir\_external\_provisioner\_version](#input\_nfs\_subdir\_external\_provisioner\_version) | Version of nfs\_subdir\_external\_provisioner\_version helm chart | `string` | `"4.0.18"` | no |
| <a name="input_node_bootstrap_arguments"></a> [node\_bootstrap\_arguments](#input\_node\_bootstrap\_arguments) | Additional arguments when bootstrapping the EKS node. | `string` | `""` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | The root device size for the worker nodes. | `string` | `"150"` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | n/a | `any` | n/a | yes |
| <a name="input_node_user_data"></a> [node\_user\_data](#input\_node\_user\_data) | Additional user data used when bootstrapping the EC2 instance. | `string` | `""` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | n/a | `string` | `"kube-oidc-proxy"` | no |
| <a name="input_oidc_config_name"></a> [oidc\_config\_name](#input\_oidc\_config\_name) | n/a | `string` | `"indico-google-ws"` | no |
| <a name="input_oidc_enabled"></a> [oidc\_enabled](#input\_oidc\_enabled) | Enable OIDC Auhentication | `bool` | `true` | no |
| <a name="input_oidc_groups_claim"></a> [oidc\_groups\_claim](#input\_oidc\_groups\_claim) | n/a | `string` | `"groups"` | no |
| <a name="input_oidc_groups_prefix"></a> [oidc\_groups\_prefix](#input\_oidc\_groups\_prefix) | n/a | `string` | `"oidcgroup:"` | no |
| <a name="input_oidc_issuer_url"></a> [oidc\_issuer\_url](#input\_oidc\_issuer\_url) | n/a | `string` | `"https://keycloak.devops.indico.io/auth/realms/GoogleAuth"` | no |
| <a name="input_oidc_username_claim"></a> [oidc\_username\_claim](#input\_oidc\_username\_claim) | n/a | `string` | `"sub"` | no |
| <a name="input_oidc_username_prefix"></a> [oidc\_username\_prefix](#input\_oidc\_username\_prefix) | n/a | `string` | `"oidcuser:"` | no |
| <a name="input_on_prem_test"></a> [on\_prem\_test](#input\_on\_prem\_test) | n/a | `bool` | `false` | no |
| <a name="input_opentelemetry_collector_version"></a> [opentelemetry\_collector\_version](#input\_opentelemetry\_collector\_version) | n/a | `string` | `"0.108.0"` | no |
| <a name="input_per_unit_storage_throughput"></a> [per\_unit\_storage\_throughput](#input\_per\_unit\_storage\_throughput) | Throughput for each 1 TiB or storage (max 200) for RWX FSx | `number` | `100` | no |
| <a name="input_performance_bucket"></a> [performance\_bucket](#input\_performance\_bucket) | Add permission to connect to indico-locust-benchmark-test-results | `bool` | `false` | no |
| <a name="input_pre-reqs-values-yaml-b64"></a> [pre-reqs-values-yaml-b64](#input\_pre-reqs-values-yaml-b64) | n/a | `string` | `"Cg=="` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | CIDR ranges for the private subnets | `list(string)` | n/a | yes |
| <a name="input_private_subnet_tag_name"></a> [private\_subnet\_tag\_name](#input\_private\_subnet\_tag\_name) | n/a | `string` | `"Name"` | no |
| <a name="input_private_subnet_tag_value"></a> [private\_subnet\_tag\_value](#input\_private\_subnet\_tag\_value) | n/a | `string` | `"*private*"` | no |
| <a name="input_public_ip"></a> [public\_ip](#input\_public\_ip) | Should the cluster manager have a public IP assigned | `bool` | `true` | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR ranges for the public subnets | `list(string)` | n/a | yes |
| <a name="input_public_subnet_tag_name"></a> [public\_subnet\_tag\_name](#input\_public\_subnet\_tag\_name) | n/a | `string` | `"Name"` | no |
| <a name="input_public_subnet_tag_value"></a> [public\_subnet\_tag\_value](#input\_public\_subnet\_tag\_value) | n/a | `string` | `"*public*"` | no |
| <a name="input_readapi_customer"></a> [readapi\_customer](#input\_readapi\_customer) | Name of the customer readapi is being deployed in behalf. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region in which to launch the indico stack | `string` | `"us-east-1"` | no |
| <a name="input_restore_snapshot_enabled"></a> [restore\_snapshot\_enabled](#input\_restore\_snapshot\_enabled) | Flag for restoring cluster from snapshot | `bool` | `false` | no |
| <a name="input_restore_snapshot_name"></a> [restore\_snapshot\_name](#input\_restore\_snapshot\_name) | Name of snapshot in account's s3 bucket | `string` | `""` | no |
| <a name="input_s3_endpoint_enabled"></a> [s3\_endpoint\_enabled](#input\_s3\_endpoint\_enabled) | If set to true, an S3 VPC endpoint will be created. If this variable is set, the `region` variable must also be set | `bool` | `false` | no |
| <a name="input_secrets_operator_enabled"></a> [secrets\_operator\_enabled](#input\_secrets\_operator\_enabled) | Use to enable the secrets operator which is used for maintaining thanos connection | `bool` | `true` | no |
| <a name="input_sg_tag_name"></a> [sg\_tag\_name](#input\_sg\_tag\_name) | n/a | `string` | `"Name"` | no |
| <a name="input_sg_tag_value"></a> [sg\_tag\_value](#input\_sg\_tag\_value) | n/a | `string` | `"*-allow-subnets"` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip taking a final snapshot before deletion; not recommended to enable | `bool` | `false` | no |
| <a name="input_snapshot_id"></a> [snapshot\_id](#input\_snapshot\_id) | The ebs snapshot of read-only data to use | `string` | `""` | no |
| <a name="input_sqs_sns"></a> [sqs\_sns](#input\_sqs\_sns) | Flag for enabling SQS/SNS | `bool` | `true` | no |
| <a name="input_ssl_static_secret_name"></a> [ssl\_static\_secret\_name](#input\_ssl\_static\_secret\_name) | secret\_name for static ssl certificate | `string` | `"indico-ssl-static-cert"` | no |
| <a name="input_storage_capacity"></a> [storage\_capacity](#input\_storage\_capacity) | Storage capacity in GiB for RWX FSx | `number` | `1200` | no |
| <a name="input_storage_gateway_size"></a> [storage\_gateway\_size](#input\_storage\_gateway\_size) | The size of the storage gateway VM | `string` | `"m5.xlarge"` | no |
| <a name="input_submission_expiry"></a> [submission\_expiry](#input\_submission\_expiry) | The number of days to retain submissions | `number` | `30` | no |
| <a name="input_subnet_az_zones"></a> [subnet\_az\_zones](#input\_subnet\_az\_zones) | Availability zones for the subnets | `list(string)` | n/a | yes |
| <a name="input_terraform_smoketests_enabled"></a> [terraform\_smoketests\_enabled](#input\_terraform\_smoketests\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_terraform_vault_mount_path"></a> [terraform\_vault\_mount\_path](#input\_terraform\_vault\_mount\_path) | n/a | `string` | `"terraform"` | no |
| <a name="input_thanos_cluster_ca_certificate"></a> [thanos\_cluster\_ca\_certificate](#input\_thanos\_cluster\_ca\_certificate) | n/a | `string` | `"provided from the varset thanos"` | no |
| <a name="input_thanos_cluster_host"></a> [thanos\_cluster\_host](#input\_thanos\_cluster\_host) | n/a | `string` | `"provided from the varset thanos"` | no |
| <a name="input_thanos_cluster_name"></a> [thanos\_cluster\_name](#input\_thanos\_cluster\_name) | n/a | `string` | `"thanos"` | no |
| <a name="input_thanos_enabled"></a> [thanos\_enabled](#input\_thanos\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_thanos_grafana_admin_password"></a> [thanos\_grafana\_admin\_password](#input\_thanos\_grafana\_admin\_password) | n/a | `string` | `"provided from the varset thanos"` | no |
| <a name="input_thanos_grafana_admin_username"></a> [thanos\_grafana\_admin\_username](#input\_thanos\_grafana\_admin\_username) | n/a | `string` | `"provided from the varset devops-tools-cluster"` | no |
| <a name="input_uploads_expiry"></a> [uploads\_expiry](#input\_uploads\_expiry) | The number of days to retain uploads | `number` | `30` | no |
| <a name="input_use_acm"></a> [use\_acm](#input\_use\_acm) | create cluster that will use acm | `bool` | `false` | no |
| <a name="input_use_nlb"></a> [use\_nlb](#input\_use\_nlb) | If true this will create a NLB loadbalancer instead of a classic VPC ELB | `bool` | `false` | no |
| <a name="input_use_static_ssl_certificates"></a> [use\_static\_ssl\_certificates](#input\_use\_static\_ssl\_certificates) | use static ssl certificates for clusters which cannot use certmanager and external dns. | `bool` | `false` | no |
| <a name="input_vault_address"></a> [vault\_address](#input\_vault\_address) | n/a | `string` | `"https://vault.devops.indico.io"` | no |
| <a name="input_vault_mount_path"></a> [vault\_mount\_path](#input\_vault\_mount\_path) | n/a | `string` | `"terraform"` | no |
| <a name="input_vault_password"></a> [vault\_password](#input\_vault\_password) | n/a | `any` | n/a | yes |
| <a name="input_vault_secrets_operator_version"></a> [vault\_secrets\_operator\_version](#input\_vault\_secrets\_operator\_version) | n/a | `string` | `"0.7.0"` | no |
| <a name="input_vault_username"></a> [vault\_username](#input\_vault\_username) | n/a | `any` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | The VPC for the entire indico stack | `string` | n/a | yes |
| <a name="input_vpc_flow_logs_iam_role_arn"></a> [vpc\_flow\_logs\_iam\_role\_arn](#input\_vpc\_flow\_logs\_iam\_role\_arn) | The IAM role to use for the flow logs | `string` | `""` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | The VPC name | `string` | `"indico_vpc"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_arn"></a> [acm\_arn](#output\_acm\_arn) | arn of the acm |
| <a name="output_api_models_s3_bucket_name"></a> [api\_models\_s3\_bucket\_name](#output\_api\_models\_s3\_bucket\_name) | Name of the api-models s3 bucket |
| <a name="output_argo_branch"></a> [argo\_branch](#output\_argo\_branch) | n/a |
| <a name="output_argo_path"></a> [argo\_path](#output\_argo\_path) | n/a |
| <a name="output_argo_repo"></a> [argo\_repo](#output\_argo\_repo) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_cluster_region"></a> [cluster\_region](#output\_cluster\_region) | n/a |
| <a name="output_data_s3_bucket_name"></a> [data\_s3\_bucket\_name](#output\_data\_s3\_bucket\_name) | Name of the data s3 bucket |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | n/a |
| <a name="output_efs_filesystem_id"></a> [efs\_filesystem\_id](#output\_efs\_filesystem\_id) | ID of the EFS filesystem |
| <a name="output_fsx_rox_id"></a> [fsx\_rox\_id](#output\_fsx\_rox\_id) | Read only filesystem |
| <a name="output_fsx_rwx_id"></a> [fsx\_rwx\_id](#output\_fsx\_rwx\_id) | Read write filesystem |
| <a name="output_fsx_storage_fsx_rwx_dns_name"></a> [fsx\_storage\_fsx\_rwx\_dns\_name](#output\_fsx\_storage\_fsx\_rwx\_dns\_name) | n/a |
| <a name="output_fsx_storage_fsx_rwx_mount_name"></a> [fsx\_storage\_fsx\_rwx\_mount\_name](#output\_fsx\_storage\_fsx\_rwx\_mount\_name) | n/a |
| <a name="output_fsx_storage_fsx_rwx_subnet_id"></a> [fsx\_storage\_fsx\_rwx\_subnet\_id](#output\_fsx\_storage\_fsx\_rwx\_subnet\_id) | n/a |
| <a name="output_fsx_storage_fsx_rwx_volume_handle"></a> [fsx\_storage\_fsx\_rwx\_volume\_handle](#output\_fsx\_storage\_fsx\_rwx\_volume\_handle) | n/a |
| <a name="output_git_branch"></a> [git\_branch](#output\_git\_branch) | n/a |
| <a name="output_git_sha"></a> [git\_sha](#output\_git\_sha) | n/a |
| <a name="output_harbor-api-token"></a> [harbor-api-token](#output\_harbor-api-token) | n/a |
| <a name="output_harness_delegate_name"></a> [harness\_delegate\_name](#output\_harness\_delegate\_name) | n/a |
| <a name="output_ipa_version"></a> [ipa\_version](#output\_ipa\_version) | n/a |
| <a name="output_key_pem"></a> [key\_pem](#output\_key\_pem) | Generated private key for key pair |
| <a name="output_kube_ca_certificate"></a> [kube\_ca\_certificate](#output\_kube\_ca\_certificate) | n/a |
| <a name="output_kube_host"></a> [kube\_host](#output\_kube\_host) | n/a |
| <a name="output_kube_token"></a> [kube\_token](#output\_kube\_token) | n/a |
| <a name="output_local_registry_password"></a> [local\_registry\_password](#output\_local\_registry\_password) | n/a |
| <a name="output_local_registry_username"></a> [local\_registry\_username](#output\_local\_registry\_username) | n/a |
| <a name="output_monitoring-password"></a> [monitoring-password](#output\_monitoring-password) | n/a |
| <a name="output_monitoring-username"></a> [monitoring-username](#output\_monitoring-username) | n/a |
| <a name="output_monitoring_enabled"></a> [monitoring\_enabled](#output\_monitoring\_enabled) | n/a |
| <a name="output_ns"></a> [ns](#output\_ns) | n/a |
| <a name="output_s3_role_id"></a> [s3\_role\_id](#output\_s3\_role\_id) | ID of the S3 role |
| <a name="output_smoketest_chart_version"></a> [smoketest\_chart\_version](#output\_smoketest\_chart\_version) | n/a |
| <a name="output_wafv2_arn"></a> [wafv2\_arn](#output\_wafv2\_arn) | arn of the wafv2 acl |
| <a name="output_zerossl"></a> [zerossl](#output\_zerossl) | n/a |
