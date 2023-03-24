
resource "github_repository_file" "argocd-application-yaml" {
  count = var.argo_enabled == true && var.ipa_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo[0].name
  branch              = var.argo_branch
  file                = "${var.argo_path}/ipa_application.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      content
    ]
  }

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
    account: ${var.account}
    name: ${var.label}
  annotations:
    avp.kubernetes.io/path: tools/argo/data/ipa-deploy
spec:
  destination:
    server: ${var.kubernetes_host}
    namespace: ${var.ipa_namespace}
  project: "${lower("${var.account}.${var.label}.${var.region}")}"
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
        
        - name: HELM_TF_COD_VALUES
          value: |
            global:
              secretRefs:
                - indico-generated-secrets
                - indico-static-secrets
                - rabbitmq
                - workload-identity
                - azure-storage-key
            kafka-strimzi:
              enabled: true
              podSecurityContext:
                fsGroup: 1001
              postgres:
                app:
                  # -- By default, this points to the crunchy-postgres service for the application database
                  host: postgres-data-primary.${var.ipa_namespace}.svc
                  user: indico
                metrics:
                  # -- By default, this points to the crunchy-postgres service for the metrics database
                  host: postgres-data-primary.${var.ipa_namespace}.svc
                  user: indico
            nvidia-device-plugin:
              enabled: ${!var.is_openshift}
          
            worker:
              autoscaling:
                authentication:
                  enabled: false
                serverAddress: ${local.prometheus_address}
                highmem:
                  serverAddress: ${local.prometheus_address}
            reloader:
              isOpenshift: ${var.is_openshift}
            aws-node-termination:
              enabled: false
            app-edge:
              openshift:
                enabled: ${var.is_openshift}
              ingress:
                labels:
                  "acme.cert-manager.io/http01-solver": "true"
            rainbow-nginx:
              openshift:
                enabled: ${var.is_openshift}
            runtime-scanner:
              enabled: ${replace(lower(var.account), "indico", "") == lower(var.account) ? "false" : "true"}
              labels:
                prometheus: indico-general
              authentication:
                ingressUser: ${var.monitoring_username}
                ingressPassword: ${var.monitoring_password}
        
        - name: HELM_VALUES
          value: |
            ${base64decode(var.ipa_values)}    
EOT
}

resource "argocd_application" "ipa" {
  depends_on = [
    github_repository_file.argocd-application-yaml,
  ]

  count = var.argo_enabled == true && var.ipa_enabled == true ? 1 : 0

  wait = true

  metadata {
    name      = lower("${var.account}-${var.region}-${var.label}-deploy-ipa")
    namespace = "argo"
    labels = {
      test = "true"
    }
  }

  spec {

    project = lower("${var.account}.${var.label}.${var.region}")

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
  for_each = var.argo_enabled == true ? var.applications : {}

  repository          = data.github_repository.argo-github-repo[0].name
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
  name: ${lower("${var.account}-${var.region}-${var.label}-${each.value.name}")} 
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
     avp.kubernetes.io/path: ${each.value.vaultPath}
  labels:
    app: ${each.value.name}
    region: ${var.region}
    account: ${var.account}
    name: ${var.label}
spec:
  destination:
    server: ${var.kubernetes_host}
    namespace: ${each.value.namespace}
  project: "${lower("${var.account}.${var.label}.${var.region}")}"
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

