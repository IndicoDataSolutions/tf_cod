
resource "aws_route53_record" "monitoring-caa" {
  count   = var.hibernation_enabled == true ? 1 : 0
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = lower("monitoring.${local.dns_name}")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"sectigo.com\""
  ]
}

resource "helm_release" "ingress" {
  depends_on = [
    helm_release.ipa-pre-requisites
  ]

  count = var.hibernation_enabled == true ? 1 : 0

  verify           = false
  name             = "nginx-ingress"
  create_namespace = true
  namespace        = "ingress-basic"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "3.25.0"

  values = [<<EOF
controller:
  service:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: ${lower("monitoring.${local.dns_name}")}

  admissionWebhooks:
    patch:
      nodeSelector.beta.kubernetes.io/os: linux

  nodeSelector.beta.kubernetes.io/os: linux
  replicaCount: 3

defaultBackend:
  nodeSelector.beta.kubernetes.io/os: linux

rbac:
  create: true
  EOF
  ]
}


resource "github_repository_file" "hibernation-autoscaler-yaml" {
  count = var.hibernation_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/hibernation-autoscaler.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  content = <<EOT
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${lower("${var.aws_account}-${var.region}-${var.name}-hibernation-autoscaler")}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: autoscaler
    component: core
spec:
  project: ${module.argo-registration.argo_project_name}
  source:
    repoURL: 'https://github.com/IndicoDataSolutions/indico-devops-autoscaler-deploy.git'
    path: indico-autoscaler
    targetRevision: indico-nonprod
    helm:
      releaseName: ca
      parameters:
        - name: global.prometheus_release
          value: ${var.label}-autoscaler-prometheus
      values: |
        replicaCount: 2
        alertmanagerconfig:
          slackChannel: ${var.label}-alerts
        indico:
          hibernation:
            ready_wait_timeout: 10  #minutes before all must be ready after unhibernate
                                
            activeTimes: # Times when hibernate will not run if called
              - name: weekdays
                timezone: 'US/Eastern'
                days: [1, 2, 3, 4, 5] # m,t,w,th,f
                times:
                  - startTime: "07:00" # 7am
                    endTime: "21:00"   # 9pm
            
            sleepTimes: # Times when unhibernate will be ignored.
              - name: hibernate_release_test
                days: [1] #mon
                times:
                  - startTime: "21:00" # 9pm
                    endTime: "07:00" # 7am
              - name: weekends
                timezone: 'US/Eastern'
                days: [0, 6] # sun, sat
                times:
                  - startTime: "01:00" # 1 am
                    endTime: "07:00"   # 7 am
  
  destination:
    server: "${module.cluster.kubernetes_host}"
    namespace: default
  syncPolicy:
    automated: {}
    syncOptions:
      - CreateNamespace=true
EOT
}

resource "github_repository_file" "hibernation-exporter-yaml" {
  count = var.hibernation_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/hibernation-exporter.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  content = <<EOT
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${lower("${var.aws_account}-${var.region}-${var.name}-hibernation-exporter")}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: autoscaler
    component: exporter
spec:
  project: ${module.argo-registration.argo_project_name}
  source:
    repoURL: 'https://github.com/IndicoDataSolutions/indico-devops-autoscaler-deploy.git'
    path: app-edge-exporter
    targetRevision: indico-nonprod
    helm:
      releaseName: ca
      parameters:
        - name: global.prometheus_release
          value: ${var.label}-autoscaler-prometheus
  destination:
    server: "${module.cluster.kubernetes_host}"
    namespace: default
  syncPolicy:
    automated: {}
    syncOptions:
      - CreateNamespace=true
EOT
}

resource "github_repository_file" "hibernation-prometheus-yaml" {
  count = var.hibernation_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/hibernation-prometheus.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  content = <<EOT
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${lower("${var.aws_account}-${var.region}-${var.name}-hibernation-prometheus")}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: autoscaler
    component: monitoring
spec:
  project: ${module.argo-registration.argo_project_name}
  source:
    repoURL: 'https://github.com/IndicoDataSolutions/indico-devops-autoscaler-deploy.git'
    path: prometheus-operator
    targetRevision: indico-nonprod
    plugin:
      name: kustomized-helm-release-values
      env:
        - name: HELM_RELEASE
          value: ca
        
        - name: HELM_VALUES
          value: |
            global:
              host: ${lower("${var.label}.${var.aws_account}.indico.io")}
              prometheus_release: ${var.label}-autoscaler-prometheus
            kube-prometheus-stack:
              alertmanager:
                alertmanagerSpec:
                  externalUrl: https://${lower("monitoring.${local.dns_name}")}/kube-alertmanager/
                
                ingress:
                  annotations:
                    kubernetes.io/ingress.class: "nginx"
                    cert-manager.io/cluster-issuer: zerossl  
                  hosts:
                    - ${lower("monitoring.${local.dns_name}")}
                  tls:
                    - secretName: alertmanager-tls
                      hosts:
                        - ${lower("monitoring.${local.dns_name}")}
              prometheus:
                prometheusSpec:
                  externalUrl: https:/${lower("monitoring.${local.dns_name}")}/kube-prometheus/
                
                ingress:
                  annotations:
                    kubernetes.io/ingress.class: "nginx"
                    cert-manager.io/cluster-issuer: zerossl
                  hosts:
                    - ${lower("monitoring.${local.dns_name}")}
                  tls:
                    - secretName: prometheus-tls
                      hosts:
                        - ${lower("monitoring.${local.dns_name}")}
              grafana:
                ingress:
                  annotations:
                    kubernetes.io/ingress.class: "nginx"
                    cert-manager.io/cluster-issuer: zerossl
                  hosts:
                    - ${lower("monitoring.${local.dns_name}")}
                  tls:
                    - secretName: grafana-tls
                      hosts:
                        - ${lower("monitoring.${local.dns_name}")}
  destination:
    server: "${module.cluster.kubernetes_host}"
    namespace: default
  syncPolicy:
    automated: 
      prune: true
      selfHeal: false
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
EOT
}

resource "github_repository_file" "hibernation-secrets-yaml" {
  count = var.hibernation_enabled == true ? 1 : 0

  repository          = data.github_repository.argo-github-repo.name
  branch              = var.argo_branch
  file                = "${var.argo_path}/hibernation-secrets.yaml"
  commit_message      = var.message
  overwrite_on_create = true

  content = <<EOT
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${lower("${var.aws_account}-${var.region}-${var.name}-hibernation-secrets")}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    app: autoscaler
    component: secrets
spec:
  project: ${module.argo-registration.argo_project_name}
  source:
    repoURL: 'https://github.com/IndicoDataSolutions/indico-devops-autoscaler-deploy.git'
    path: indico-autoscaler/secrets2
    targetRevision: indico-nonprod
    plugin:
      name: argocd-vault-plugin
  destination:
    server: "${module.cluster.kubernetes_host}"
    namespace: default
  syncPolicy:
    automated: {}
    syncOptions:
      - CreateNamespace=true
EOT
}
