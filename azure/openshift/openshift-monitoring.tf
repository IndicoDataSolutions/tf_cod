

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

resource "kubectl_manifest" "custom-metrics-autoscaler" {
  depends_on = [
    module.cluster
  ]

  yaml_body = <<YAML
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/openshift-custom-metrics-autoscaler-operator.openshift-keda: ""
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



