

resource "kubectl_manifest" "cluster-monitoring-config" {
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
    kubectl_manifest.cluster-monitoring-config
  ]

  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = "openshift-keda"
  }
}


# Create SA to access thanos queries
resource "kubernetes_service_account_v1" "querier" {
  depends_on = [
    kubernetes_namespace.openshift-keda
  ]
  metadata {
    name      = "querier"
    namespace = "openshift-keda"
  }
  secret {
    name = "querier"
  }
  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "querier" {
  depends_on = [
    kubernetes_service_account_v1.querier,
    kubernetes_namespace.openshift-keda
  ]

  metadata {
    name      = "thanos-api-querier"
    namespace = "openshift-keda"
    annotations = {
      "kubernetes.io/service-account.name" = "querier"
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role_binding" "querier" {
  depends_on = [
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
    name      = "querier"
    namespace = "openshift-keda"
  }
}



resource "kubectl_manifest" "custom-metrics-operator-group" {
  depends_on = [
    kubernetes_namespace.openshift-keda
  ]

  yaml_body = <<YAML
apiVersion: "operators.coreos.com/v1"
kind: "OperatorGroup"
metadata:
  generateName: "openshift-keda-"
  name: "openshift-keda"
  namespace: "openshift-keda"
YAML
}


resource "kubectl_manifest" "custom-metrics-autoscaler" {
  depends_on = [
    kubectl_manifest.custom-metrics-operator-group,
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
    kubectl_manifest.custom-metrics-autoscaler
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  # login
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${var.resource_group_name}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/wait-for-subscription.sh openshift-keda openshift-custom-metrics-autoscaler-operator"
  }
}



resource "kubectl_manifest" "keda-controller" {
  depends_on = [
    kubectl_manifest.custom-metrics-autoscaler,
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
    kubectl_manifest.keda-controller,
    kubernetes_secret_v1.querier
  ]
  yaml_body = <<YAML
apiVersion: keda.sh/v1alpha1
kind: ClusterTriggerAuthentication
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
