

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
    prometheus:
      listenLocal: false 
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



# kc edit prometheus -n openshift-user-workload-monitoring user-workload
# kubectl patch storageclass managed-premium -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
resource "null_resource" "patch-user-monitor" {
  depends_on = [
    module.cluster,
    kubectl_manifest.prometheus-service
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
    command     = <<EOF
  kubectl patch --type=merge prometheus  -n openshift-user-workload-monitoring user-workload -p '{"spec": {"listenLocal":false}}'
EOF
  }
}


