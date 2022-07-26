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



resource "helm_release" "ipa-crds" {
  depends_on = [
    module.cluster
  ]

  verify           = false
  name             = "ipa-crds"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "ipa-crds"
  version          = var.ipa_crds_version
  wait             = true

  values = [<<EOF
  crunchy-pgo:
    enabled: true
  cert-manager:
    nodeSelector:
      kubernetes.io/os: linux
    webhook:
      nodeSelector:
        kubernetes.io/os: linux
    cainjector:
      nodeSelector:
        kubernetes.io/os: linux
    enabled: true
    installCRDs: true
 EOF
  ]
}

resource "time_sleep" "wait_5_minutes_after_crds" {
  depends_on = [helm_release.ipa-crds]

  create_duration = "5m"
}

resource "helm_release" "ipa-pre-requisites" {
  depends_on = [
    time_sleep.wait_5_minutes_after_crds,
    module.cluster,
    module.fsx-storage,
    helm_release.ipa-crds
  ]

  verify           = false
  name             = "ipa-pre-reqs"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "ipa-pre-requisites"
  version          = var.ipa_pre_reqs_version
  wait             = true
  timeout          = "1800" # 30 minutes

  values = [<<EOF
secrets:
  rabbitmq:
    create: true
  
  general:
    create: true

apiModels:
  enabled: ${var.restore_snapshot_enabled == true ? false : true}

external-dns:
  enabled: true
  provider: aws
  aws:
    zoneType: public
    region: ${var.region}

  policy: sync
  sources:
    - service
    - ingress

cluster-autoscaler:
  cluster-autoscaler:
    awsRegion: ${var.region}
    image:
      tag: "v1.20.0"
    autoDiscovery:
      clusterName: "${local.cluster_name}"
      
storage:
  pvcSpec:
    csi:
      driver: fsx.csi.aws.com
      volumeAttributes:
        dnsname: ${module.fsx-storage.fsx-rwx.dns_name}
        mountname: ${module.fsx-storage.fsx-rwx.mount_name}
      volumeHandle: ${module.fsx-storage.fsx-rwx.id}
  indicoStorageClass:
    enabled: true
    name: indico-sc
    provisioner: fsx.csi.aws.com
    parameters:
      securityGroupIds: ${local.security_group_id}
      subnetId: ${module.fsx-storage.fsx-rwx.subnet_ids[0]}

crunchy-postgres:
  enabled: true
  postgres-data:
    metadata:
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    instances:
    - affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node_group
                operator: In
                values:
                - pgo-workers
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: postgres-operator.crunchydata.com/cluster
                operator: In
                values:
                - postgres-data
              - key: postgres-operator.crunchydata.com/instance-set
                operator: In
                values:
                - pgha1
            topologyKey: kubernetes.io/hostname
      metadata:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      dataVolumeClaimSpec:
        storageClassName: encrypted-gp2
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 30Gi
      name: pgha1
      replicas: 2
      resources:
        requests:
          cpu: 500m
          memory: 3000Mi
      tolerations:
        - effect: NoSchedule
          key: indico.io/crunchy
          operator: Exists
    pgBackRestConfig:
      global:
        repo1-path: /pgbackrest/postgres-data/repo1
        repo1-retention-full: '5'
        repo1-s3-key-type: auto
        repo1-s3-kms-key-id: "${module.kms_key.key_arn}"
        repo1-s3-role: ${module.cluster.s3_role_id}
      repos:
      - name: repo1
        s3:
          bucket: ${module.s3-storage.pgbackup_s3_bucket_name}
          endpoint: s3.${var.region}.amazonaws.com
          region: ${var.region}
        schedules:
          full: 30 4 * * *
          incremental: 0 */1 * * *
    imagePullSecrets:
      - name: harbor-pull-secret
    users:
    - databases:
      - noct
      - cyclone
      - crowdlabel
      - moonbow
      - elmosfire
      - elnino
      - sunbow
      - doctor
      name: indico
      options: SUPERUSER CREATEROLE CREATEDB REPLICATION BYPASSRLS
  postgres-metrics:
    metadata:
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    instances:
    - affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node_group
                operator: In
                values:
                - pgo-workers
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: postgres-operator.crunchydata.com/cluster
                operator: In
                values:
                - postgres-metrics
              - key: postgres-operator.crunchydata.com/instance-set
                operator: In
                values:
                - pgha1
            topologyKey: kubernetes.io/hostname
      metadata:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      dataVolumeClaimSpec:
        storageClassName: encrypted-gp2
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 30Gi
      name: pgha1
      replicas: 2
      resources:
        requests:
          cpu: 500m
          memory: 3000Mi
      tolerations:
        - effect: NoSchedule
          key: indico.io/crunchy
          operator: Exists
    pgBackRestConfig:
      global:
        repo1-path: /pgbackrest/postgres-metrics/repo1
        repo1-retention-full: '5'
        repo1-s3-key-type: auto
        repo1-s3-kms-key-id: "${module.kms_key.key_arn}"
        repo1-s3-role: ${module.cluster.s3_role_id}
      repos:
      - name: repo1
        s3:
          bucket: ${module.s3-storage.pgbackup_s3_bucket_name}
          endpoint: s3.${var.region}.amazonaws.com
          region: ${var.region}
        schedules:
          full: 30 4 * * *
          incremental: 0 */1 * * *
    imagePullSecrets:
      - name: harbor-pull-secret
    users:
    - databases:
      - meteor
      name: indico
      options: SUPERUSER CREATEROLE CREATEDB REPLICATION BYPASSRLS
  
  EOF
  ]
}


data "github_repository" "argo-github-repo" {
  full_name = "IndicoDataSolutions/${var.argo_repo}"
}

resource "github_repository_file" "argocd-application-yaml" {
  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_application.yaml"
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
spec:
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
        - name: RELEASE_NAME
          value: ipa

        - name: HELM_VALUES
          value: |
            global:
              appDomains:
                - "${local.dns_name}"
            
            secrets:
              ocr_license_key: <OCR_LICENSE_KEY>

            rabbitmq:
              enabled: true

            configs:
              allowed_origins: "ALLOW_ALL"
              postgres:
                app:
                  user: "indico"
                metrics:
                  user: "indico"

                                    
            ${base64decode(var.ipa_values)}    
EOT
}


resource "local_file" "kubeconfig" {
  content  = module.cluster.kubectl_config
  filename = "${path.module}/module.kubeconfig"
}


resource "argocd_application" "ipa" {
  depends_on = [
    local_file.kubeconfig,
    helm_release.ipa-pre-requisites,
    module.argo-registration,
    kubernetes_job.snapshot-restore-job,
    github_repository_file.argocd-application-yaml,
    github_repository_file.hibernation-autoscaler-yaml,
    github_repository_file.hibernation-exporter-yaml,
    github_repository_file.hibernation-prometheus-yaml,
    github_repository_file.hibernation-secrets-yaml
  ]

  count = var.ipa_enabled == true ? 1 : 0

  wait = true

  metadata {
    name      = lower("${var.aws_account}-${var.region}-${var.name}-deploy-ipa")
    namespace = "argo"
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
    }

    sync_policy {
      automated = {
        prune       = true
        self_heal   = false
        allow_empty = false
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argo"
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
  name: ${lower("${var.aws_account}-${var.region}-${var.name}-${each.value.name}")} 
  finalizers:
    - resources-finalizer.argocd.argoproj.io
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
      - CreateNamespace=true
  source:
    chart: ${each.value.chart}
    repoURL: ${each.value.repo}
    targetRevision: ${each.value.version}
    helm:
      releaseName: ${each.value.name}
      values: |
        ${base64decode(each.value.values)}    
EOT
}

