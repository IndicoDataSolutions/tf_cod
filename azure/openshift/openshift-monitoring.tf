
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
    targetPort: web
  - name: grpc
    port: 10901
    protocol: TCP
    targetPort: grpc
  selector:
    app.kubernetes.io/name: prometheus
  sessionAffinity: None
  type: ClusterIP
YAML
}
