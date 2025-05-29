
# Create secrets for the service mesh.
resource "kubectl_manifest" "linkerd-issuer-secret" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-crds, time_sleep.wait_1_minutes_after_crds]
  yaml_body = <<YAML
    apiVersion: "secrets.hashicorp.com/v1beta1"
    kind: "VaultStaticSecret"
    metadata:
      name:  linkerd-identity-issuer
      namespace: ${var.namespace}
    spec:
      type: "kv-v2"
      namespace: ${var.namespace}
      mount: customer-${var.account_name}
      path: environments/${var.load_environment == "" ? var.environment : lower(var.load_environment)}/issuer
      refreshAfter: 60s
      destination:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
          reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "${var.service_mesh_namespace}"
        create: true
        name: linkerd-identity-issuer
      vaultAuthRef: default
  YAML
}
resource "kubectl_manifest" "linkerd-identity-trust-roots-bundle" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [kubectl_manifest.linkerd-issuer-secret, helm_release.linkerd-crds]
  yaml_body  = <<YAML
    apiVersion: trust.cert-manager.io/v1alpha1
    kind: Bundle
    metadata:
      name: linkerd-identity-trust-roots  # The bundle name will also be used for the target
      namespace: ${var.namespace}
    spec:
      sources:
      - secret:
          name: "linkerd-identity-issuer"
          key: "ca.crt"
      target:
        configMap:
          key: "ca-bundle.crt"
        namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: "${var.service_mesh_namespace}"
  YAML
}

resource "helm_release" "linkerd-crds" {
  count            = var.enable_service_mesh ? 1 : 0
  depends_on       = [time_sleep.wait_1_minutes_after_crds]
  name             = "linkerd-crds"
  chart            = "linkerd-crds"
  namespace        = var.service_mesh_namespace
  create_namespace = true
  repository       = var.helm_registry
  version          = var.linkerd_crds_version
  values           = var.linkerd_crds_values
}

resource "helm_release" "linkerd-control-plane" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-crds, kubectl_manifest.linkerd-identity-trust-roots-bundle, kubectl_manifest.linkerd-issuer-secret]
  name       = "linkerd-control-plane"
  chart      = "linkerd-control-plane"
  namespace  = var.service_mesh_namespace
  repository = var.helm_registry
  version    = var.linkerd_control_plane_version
  values     = var.linkerd_control_plane_values
}

resource "helm_release" "linkerd-viz" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-control-plane]
  name       = "linkerd-viz"
  chart      = "linkerd-viz"
  namespace  = var.service_mesh_namespace
  repository = var.helm_registry
  version    = var.linkerd_viz_version
  values     = var.linkerd_viz_values
}

resource "helm_release" "linkerd-multicluster" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-control-plane]
  name       = "linkerd-multicluster"
  chart      = "linkerd-multicluster"
  namespace  = "linkerd-multicluster"
  create_namespace = true
  repository = var.helm_registry
  version    = var.linkerd_multicluster_version
  values     = var.linkerd_multicluster_values
}

resource "kubernetes_annotations" "default-ns-annotation" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-control-plane]
  api_version = "v1"
  kind = "Namespace"
  metadata {
    name = "default"
  }
  annotations = {
    "linkerd.io/inject" = "enabled"
  }
}

# Note, the indico namespace, or namespace that contains cert-manager should not be annotated because this could cause a circular dependency with linkerd.

resource "kubernetes_annotations" "monitoring-ns-annotation" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-control-plane, kubernetes_namespace.monitoring]
  api_version = "v1"
  kind = "Namespace"
  metadata {
    name = "monitoring"
  }
  annotations = {
    "linkerd.io/inject" = "enabled"
  }
}

resource "kubernetes_annotations" "insights-ns-annotation" {
  count = var.enable_service_mesh ? 1 : 0
  depends_on = [helm_release.linkerd-control-plane]
  api_version = "v1"
  kind = "Namespace"
  metadata {
    name = "insights"
  }
  annotations = {
    "linkerd.io/inject" = "enabled"
  }
}

data "kubernetes_namespace" "existing_namespace_monitoring" {
  count = var.enable_service_mesh ? 1 : 0
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_service_mesh && data.kubernetes_namespace.existing_namespace_monitoring[0].metadata.name == null ? 1 : 0

  metadata {
    name = "monitoring"
  }
}

resource "time_sleep" "wait_1_minutes_after_service_mesh" {
  depends_on = [helm_release.linkerd-crds, helm_release.linkerd-control-plane, helm_release.linkerd-viz, helm_release.linkerd-multicluster]
  create_duration = "1m"
}