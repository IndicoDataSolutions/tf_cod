
resource "kubectl_manifest" "thanos-datasource-credentials" {
  count     = var.thanos_enabled ? 1 : 0
  provider  = kubectl.thanos-kubectl
  yaml_body = <<YAML
apiVersion: v1
stringData:
  admin-password: ${random_password.monitoring-password.result}
kind: Secret
metadata:
  name: ${replace(var.dns_name, ".", "-")}
  namespace: default
type: Opaque
  YAML
}

resource "kubectl_manifest" "thanos-datasource" {
  count      = var.thanos_enabled ? 1 : 0
  depends_on = [kubectl_manifest.thanos-datasource-credentials]
  provider   = kubectl.thanos-kubectl
  yaml_body  = <<YAML
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: ${replace(var.dns_name, ".", "-")}
  namespace: default
spec:
  valuesFrom:
    - targetPath: "secureJsonData.basicAuthPassword"
      valueFrom:
        secretKeyRef:
          name: ${replace(var.dns_name, ".", "-")}
          key: admin-password
  datasource:
    basicAuth: true
    basicAuthUser: monitoring
    editable: false
    access: proxy
    editable: true
    jsonData:
      timeInterval: 5s
      tlsSkipVerify: true
    name: ${var.dns_name}
    secureJsonData:
      basicAuthPassword: $${admin-password}
    type: prometheus
    url: https://prometheus.${var.dns_name}/prometheus
  instanceSelector:
    matchLabels:
      dashboards: external-grafana
  YAML
}

resource "kubectl_manifest" "thanos-storage-secret" {
  count     = var.thanos_enabled ? 1 : 0
  yaml_body = <<YAML
    apiVersion: "secrets.hashicorp.com/v1beta1"
    kind: "VaultStaticSecret"
    metadata:
      name:  vault-thanos-storage
      namespace: default
    spec:
      type: "kv-v2"
      namespace: default
      mount: customer-Indico-Devops
      path: thanos-storage
      refreshAfter: 60s
      rolloutRestartTargets:
        - name: prometheus-monitoring-kube-prometheus-prometheus
          kind: StatefulSet
      destination:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
        create: true
        name: thanos-storage
      vaultAuthRef: default
  YAML
}
