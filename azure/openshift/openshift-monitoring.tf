

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

# we need to create a service for prometheus that is reachable by keda
resource "kubectl_manifest" "prometheus-service" {
  depends_on = [
    module.cluster,
    kubectl_manifest.cluster-monitoring-config
  ]

  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  labels:
    operated-prometheus: "true"
  name: prometheus
  namespace: openshift-user-workload-monitoring
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: web
    port: 9090
    protocol: TCP
    targetPort: 9090
  - name: grpc
    port: 10901
    protocol: TCP
    targetPort: 10901
  selector:
    app.kubernetes.io/name: prometheus
  sessionAffinity: None
  type: ClusterIP
YAML
}
