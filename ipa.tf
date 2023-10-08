locals {
  #need to get the root of alternate_domain
  the_splits            = local.dns_name != "" ? split(".", local.dns_name) : split(".", "test.domain.com")
  the_length            = length(local.the_splits)
  the_tld               = local.the_splits[local.the_length - 1]
  the_domain            = local.the_splits[local.the_length - 2]
  alternate_domain_root = join(".", [local.the_domain, local.the_tld])

  enable_external_dns =  var.use_static_ssl_certificates == false ? true : false
  efs_values = var.include_efs == true ? [<<EOF
  aws-fsx-csi-driver:
    enabled: false
  aws-efs-csi-driver:
    enabled: true
  aws-load-balancer-controller:
    enabled: true
    ingress:
      enabled: true
      annotations:
        acme.cert-manager.io/http01-edit-in-place: "true"
        cert-manager.io/cluster-issuer: zerossl      
 EOF
  ] : []
  fsx_values = var.include_fsx == true ? [<<EOF
  aws-fsx-csi-driver:
    enabled: true
  aws-efs-csi-driver:
    enabled: false
 EOF
  ] : []
  storage_spec = var.include_fsx == true ? local.fsx_values : local.efs_values
  acm_ipa_values = var.use_acm == true ? (<<EOT
app-edge:
  alternateDomain: ""
  service:
    type: "NodePort"
    ports:
      http_port: 31755
      http_api_port: 31270
  aws-load-balancer-controller:
    enabled: true
    ingress:
      enabled: true
      annotations:
        acme.cert-manager.io/http01-edit-in-place: "true"
        cert-manager.io/cluster-issuer: zerossl      
      tls:
        - secretName: indico-ssl-cm-cert
          hosts:
            - ${local.dns_name}
      alb:
        publicSubnets: ${join(",", local.network[0].public_subnet_ids)}
        acmArn: ${aws_acm_certificate_validation.alb[0].certificate_arn}
      service:
        name: app-edge
        port: 80
      hosts:
        - host: ${local.dns_name}
          paths:
            - path: /
              pathType: Prefix
  EOT
    ) : (<<EOT
app-edge:
  alternateDomain: ""
EOT
  )
  dns_configuration_values = var.is_alternate_account_domain == "false" ? (<<EOT
clusterIssuer:
  additionalSolvers:
    - dns01:
        route53:
          region: ${var.region}
      selector:
        matchLabels:
          "acme.cert-manager.io/dns01-solver": "true"
  EOT
    ) : (<<EOT
clusterIssuer:
  additionalSolvers:
    - dns01:
        route53:
          region: ${var.region}
          role: ${var.aws_primary_dns_role_arn}
      selector:
        matchLabels:
          "acme.cert-manager.io/dns01-solver": "true"
external-dns:
  enabled: ${local.enable_external_dns}
alternate-external-dns:
  enabled: true
  logLevel: debug
  policy: sync
  txtOwnerId: "${local.dns_name}-${var.label}-${var.region}"
  domainFilters:
    - ${local.alternate_domain_root}
  extraArgs:
    - "--exclude-domains=${var.aws_account}.indico.io"
    - "--aws-assume-role=${var.aws_primary_dns_role_arn}"

  provider: aws
  aws:
    zoneType: public
    region: ${var.region}

  policy: sync
  sources:
    - ingress
EOT
  )
  runtime_scanner_ingress_values = var.use_static_ssl_certificates == true ? (<<EOT
ingress:
  enabled: true
  useStaticCertificate: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - alternate'
    nginx.ingress.kubernetes.io/auth-secret: runtime-scanner-auth
  
  useDefaultResolver: true
  labels: {}
  hosts:
    - host: scan
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: 
    - secretName: ${var.ssl_static_secret_name}
      hosts:
        - scan
  EOT
    ) : (<<EOT
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: zerossl
EOT
  )
}
resource "kubernetes_secret" "issuer-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "acme-route53"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
      "temporary.please.change/weaker-credentials-needed"       = true
    }
  }

  type = "Opaque"

  data = {
    "secret-access-key" = var.aws_secret_key
  }
}

#TODO: move to prereqs
resource "kubernetes_secret" "harbor-pull-secret" {
  depends_on = [
    module.cluster
  ]

  metadata {
    name      = "harbor-pull-secret"
    namespace = "default"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = true
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = true
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = "${base64decode(var.harbor_pull_secret_b64)}"
  }
}

data "aws_route53_zone" "aws-zone" {
  name = lower("${var.aws_account}.indico.io")
}

output "ns" {
  value = data.aws_route53_zone.aws-zone.name_servers
}


resource "github_repository_file" "pre-reqs-values-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/pre-reqs-values.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  content = base64decode(var.pre-reqs-values-yaml-b64)
}

data "github_repository_file" "data-pre-reqs-values" {
  depends_on = [
    github_repository_file.pre-reqs-values-yaml
  ]
  repository = data.github_repository.argo-github-repo.name
  branch     = var.argo_branch
  file       = var.argo_path == "." ? "helm/pre-reqs-values.values" : "${var.argo_path}/helm/pre-reqs-values.values"
}

resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    module.cluster,
    module.fsx-storage,
    data.vault_kv_secret_v2.zerossl_data,
    data.github_repository_file.data-pre-reqs-values
  ]

  verify           = false
  name             = "ipa-pre-reqs"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "ipa-pre-requisites"
  version          = var.ipa_pre_reqs_version
  wait             = false
  timeout          = "1800" # 30 minutes
  disable_webhooks = false

  values = concat(local.storage_spec, [<<EOF

cluster:
  name: ${var.label}
  region: ${var.region}
  domain: indico.io
  account: ${var.aws_account}
  argoRepo: ${var.argo_repo}
  argoBranch: ${var.argo_branch}
  argoPath: ${var.argo_path}
  ipaVersion: ${var.ipa_version}


secrets:
  rabbitmq:
    create: false
  
  general:
    create: true

  clusterIssuer:
    zerossl:
      create: true
      eabEmail: devops-sa@indico.io
      eabKid: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_KID"]}"
      eabHmacKey: "${jsondecode(data.vault_kv_secret_v2.zerossl_data.data_json)["EAB_HMAC_KEY"]}"

${local.dns_configuration_values}

monitoring:
  enabled: false
  global:
      host: "${local.dns_name}"
    
  ingress-nginx:
    enabled: true

    rbac:
      create: true

    admissionWebhooks:
      patch:
        nodeSelector.beta.kubernetes.io/os: linux
  
    defaultBackend:
      nodeSelector.beta.kubernetes.io/os: linux

  kube-prometheus-stack:
    prometheus:
      prometheusSpec:
        nodeSelector:
          node_group: static-workers

apiModels:
  enabled: true
  nodeSelector:
    node_group: static-workers

external-dns:
  enabled: ${local.enable_external_dns}
  logLevel: debug
  policy: sync
  txtOwnerId: "${var.label}-${var.region}"
  domainFilters:
    - ${lower(var.aws_account)}.indico.io.

  provider: aws
  aws:
    zoneType: public
    region: ${var.region}

  policy: sync
  sources:
    - service
    - ingress
aws-for-fluent-bit:
  enabled: true
  cloudWatchLogs:
    region: ${var.region}
    logGroupName: "/aws/eks/fluentbit-cloudwatch/${local.cluster_name}/logs"
    logGroupTemplate: "/aws/eks/fluentbit-cloudwatch/${local.cluster_name}/workload/$kubernetes['namespace_name']"
cluster-autoscaler:
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      tag: "v1.20.0"
    autoDiscovery:
      clusterName: "${local.cluster_name}"
aws-load-balancer-controller:
  enabled: ${var.use_acm}
  aws-load-balancer-controller:
    clusterName: ${var.label}
    vpcId: ${local.network[0].indico_vpc_id}
    region: ${var.region}
EOF
    ,
    <<EOT
${data.github_repository_file.data-pre-reqs-values.content}
EOT
  ])
}

resource "time_sleep" "wait_1_minutes_after_pre_reqs" {
  depends_on = [helm_release.ipa-pre-requisites]

  create_duration = "1m"
}

data "github_repository" "argo-github-repo" {
  full_name = "IndicoDataSolutions/${var.argo_repo}"
}

resource "github_repository_file" "alb-values-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/helm/alb.values"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  depends_on = [
    module.cluster,
    aws_acm_certificate_validation.alb[0]
  ]

  content = local.acm_ipa_values
}

resource "github_repository_file" "argocd-application-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_application.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }
  depends_on = [
    module.cluster,
    aws_acm_certificate_validation.alb[0]
  ]

  content = <<EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${local.argo_app_name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: cod
    region: ${var.region}
    account: ${var.aws_account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
    argocd.argoproj.io/sync-wave: "-2"
spec:
  ignoreDifferences:
    - group: apps
      jsonPointers:
        - /spec/replicas
      kind: Deployment
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: default
  project: ${module.argo-registration.argo_project_name}
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true
  source:
    chart: ipa
    repoURL: ${var.ipa_repo}
    targetRevision: ${var.ipa_version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"

        - name: RELEASE_NAME
          value: ipa         

        - name: HELM_VALUES
          value: |
            ${base64decode(var.ipa_values)}    
EOT
}


# resource "local_file" "kubeconfig" {
#   content  = module.cluster.kubectl_config
#   filename = "${path.module}/module.kubeconfig"
# }


data "vault_kv_secret_v2" "zerossl_data" {
  mount = "tools/argo"
  name  = "zerossl"
}

output "zerossl" {
  sensitive = true
  value     = data.vault_kv_secret_v2.zerossl_data.data_json
}

resource "argocd_application" "ipa" {
  depends_on = [
    # local_file.kubeconfig,
    helm_release.ipa-pre-requisites,
    time_sleep.wait_1_minutes_after_pre_reqs,
    module.argo-registration,
    github_repository_file.argocd-application-yaml
  ]

  count = var.ipa_enabled == true ? 1 : 0

  wait = true

  metadata {
    name      = lower("${var.aws_account}-${var.region}-${var.label}-deploy-ipa")
    namespace = var.argo_namespace
    labels = {
      test = "true"
    }
  }

  spec {

    project = module.argo-registration.argo_project_name

    source {
      plugin {
        name = "argocd-vault-plugin"
      }
      repo_url        = "https://github.com/IndicoDataSolutions/${var.argo_repo}.git"
      path            = var.argo_path
      target_revision = var.argo_branch
      directory {
        recurse = false
      }
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = false
        allow_empty = false
      }
    }

    destination {
      #server    = "https://kubernetes.default.svc"
      name      = "in-cluster"
      namespace = var.argo_namespace
    }
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
}


# Create Argo Application YAML for each user supplied application


resource "github_repository_file" "custom-application-yaml" {

  for_each = var.applications

  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/${each.value.name}_application.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  #TODO:
  # this allows people to make edits to the file so we don't overwrite it.
  #lifecycle {
  #  ignore_changes = [
  #    content
  #  ]
  #}

  content = <<EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${lower("${var.aws_account}-${var.region}-${var.label}-${each.value.name}")} 
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
     avp.kubernetes.io/path: ${each.value.vaultPath}
  labels:
    app: ${each.value.name}
    region: ${var.region}
    account: ${var.aws_account}
    name: ${var.label}
spec:
  destination:
    server: ${module.cluster.kubernetes_host}
    namespace: ${each.value.namespace}
  project: ${module.argo-registration.argo_project_name}
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=${each.value.createNamespace}
  source:
    chart: ${each.value.chart}
    repoURL: ${each.value.repo}
    targetRevision: ${each.value.version}
    plugin:
      name: argocd-vault-plugin-helm-values-expand-no-build
      env:
        - name: KUBE_VERSION
          value: "${var.k8s_version}"
        - name: RELEASE_NAME
          value: ${each.value.name}
        - name: HELM_VALUES
          value: |
            ${indent(12, base64decode(each.value.values))}
EOT
}