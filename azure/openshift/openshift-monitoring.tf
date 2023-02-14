

# Create SA to access thanos queries
resource "kubernetes_service_account_v1" "querier" {
  depends_on = [
    module.cluster
  ]
  metadata {
    name      = "querier"
    namespace = "default"
  }
  secret {
    name = "querier"
  }
  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "querier" {
  depends_on = [
    module.cluster,
    kubernetes_service_account_v1.querier
  ]

  metadata {
    name      = "thanos-api-querier"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name"                      = "querier"
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = "true"
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = "true"
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_binding" "querier" {
  depends_on = [
    module.cluster,
    kubernetes_secret_v1.querier
  ]

  metadata {
    name = "querier-monitoring-view"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-monitoring-view"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_secret_v1.querier.metadata.0.name
    namespace = "default"
  }
}

resource "kubectl_manifest" "cluster-monitoring-config" {
  depends_on = [
    module.cluster
  ]

  yaml_body = <<YAML
apiVersion: "v1"
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
YAML
}


resource "kubernetes_namespace" "openshift-keda" {
  depends_on = [
    module.cluster
  ]

  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = "openshift-keda"
  }
}

resource "kubectl_manifest" "custom-metrics-autoscaler" {
  depends_on = [
    module.cluster,
    kubernetes_namespace.openshift-keda
  ]

  yaml_body = <<YAML
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-custom-metrics-autoscaler-operator
  namespace: openshift-keda
spec:
  channel: stable
  installPlanApproval: Automatic
  name: openshift-custom-metrics-autoscaler-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: custom-metrics-autoscaler.v2.7.1
YAML
}


resource "null_resource" "wait-for-custom-metrics-subscription" {
  depends_on = [
    kubectl_manifest.custom-metrics-autoscaler,
    module.cluster
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  # login
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${local.resource_group_name}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/wait-for-subscription.sh openshift-keda openshift-custom-metrics-autoscaler-operator"
  }
}



resource "kubectl_manifest" "keda-controller" {
  depends_on = [
    module.cluster,
    null_resource.wait-for-custom-metrics-subscription
  ]

  yaml_body = <<YAML
apiVersion: keda.sh/v1alpha1
kind: KedaController
metadata:
  finalizers:
    - finalizer.kedacontroller.keda.k8s.io
  name: keda
  namespace: openshift-keda
spec:
  metricsServer:
    logLevel: '0'
  operator:
    logEncoder: console
    logLevel: info
  serviceAccount: {}
  watchNamespace: ''
YAML
}


resource "kubectl_manifest" "trigger-authentication" {
  depends_on = [
    module.cluster,
    kubectl_manifest.keda-controller
  ]
  yaml_body = <<YAML
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: keda-trigger-auth-prometheus
spec:
  secretTargetRef: 
  - parameter: bearerToken 
    name: thanos-api-querier
    key: token 
  - parameter: ca
    name: thanos-api-querier
    key: ca.crt
YAML
}
