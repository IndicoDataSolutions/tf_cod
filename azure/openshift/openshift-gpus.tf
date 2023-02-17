


locals {
  nfd_namespace             = "openshift-nfd"
  nvidia_operator_namespace = "nvidia-gpu-operator"
  package                   = element([for c in data.kubernetes_resource.package.object.status.channels : c.currentCSV if c.name == data.kubernetes_resource.package.object.status.defaultChannel], 0)
  channel                   = data.kubernetes_resource.package.object.status.defaultChannel
}

output "channel" {
  value = local.channel
}

# PACKAGE=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')
output "package" {
  value = local.package
}


resource "kubernetes_namespace" "gpu" {
  depends_on = [
    module.cluster
  ]
  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = local.nvidia_operator_namespace
  }
}

resource "kubectl_manifest" "gpu" {
  depends_on = [
    module.cluster,
    kubernetes_namespace.gpu
  ]
  yaml_body = <<YAML
    apiVersion: "operators.coreos.com/v1"
    kind: "OperatorGroup"
    metadata:
      name: "nvidia-gpu-operator-group"
      namespace: ${local.nvidia_operator_namespace}
    spec:
      targetNamespaces: [${local.nvidia_operator_namespace}]
  YAML
}

data "kubernetes_resource" "package" {
  depends_on = [
    module.cluster
  ]

  api_version = "packages.operators.coreos.com/v1"
  kind        = "PackageManifest"

  metadata {
    name      = "gpu-operator-certified"
    namespace = "openshift-marketplace"
  }
}

resource "kubectl_manifest" "gpu-operator-subscription" {
  depends_on = [
    module.cluster,
    kubernetes_namespace.gpu,
    data.kubernetes_resource.package
  ]

  yaml_body = <<YAML
    apiVersion: "operators.coreos.com/v1alpha1"
    kind: "Subscription"
    metadata:
      name: "gpu-operator-certified"
      namespace: ${local.nvidia_operator_namespace}
    
    spec:
      channel: "${local.channel}"
      installPlanApproval: "Automatic"
      name: "gpu-operator-certified"
      source: "certified-operators"
      sourceNamespace: "openshift-marketplace"
      startingCSV: "${local.package}"
  YAML
}


resource "null_resource" "wait-for-gpu-operator" {
  depends_on = [
    module.cluster,
    kubectl_manifest.gpu-operator-subscription
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
    command     = "${path.module}/wait-for-subscription.sh ${local.nvidia_operator_namespace} gpu-operator-certified"
  }
}

resource "kubernetes_namespace" "nfd" {
  depends_on = [
    module.cluster,
    null_resource.wait-for-gpu-operator
  ]

  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = local.nfd_namespace
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${local.resource_group_name}"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<CMD
    kubectl patch namespace openshift-nfd -p '{"metadata":{"finalizers": []}}' --type=merge || true
    CMD
  }

}


resource "kubectl_manifest" "nfd-operator" {
  depends_on = [
    null_resource.wait-for-gpu-operator,
    kubernetes_namespace.nfd
  ]

  yaml_body = <<YAML
apiVersion: "operators.coreos.com/v1"
kind: "OperatorGroup"
metadata:
  generateName: "openshift-nfd-"
  name: "openshift-nfd"
  namespace: ${local.nfd_namespace}
YAML
}

resource "kubectl_manifest" "nfd-subscription" {
  depends_on = [
    module.cluster,
    kubectl_manifest.nfd-operator
  ]

  yaml_body = <<YAML
apiVersion: "operators.coreos.com/v1alpha1"
kind: "Subscription"
metadata:
  name: "nfd"
  namespace: ${local.nfd_namespace}

spec:
  channel: "stable"
  installPlanApproval: "Automatic"
  name: "nfd"
  source: "redhat-operators"
  sourceNamespace: "openshift-marketplace"
YAML

  # wait until ready
  #wait {
  #  fields = {
  #    "status.conditions[0].type"   = "CatalogSourcesUnhealthy"
  #    "status.conditions[0].status" = "False"
  #  }
}


resource "null_resource" "wait-for-nfd-subscription" {
  depends_on = [
    kubectl_manifest.nfd-subscription,
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
    command     = "${path.module}/wait-for-subscription.sh ${local.nfd_namespace} nfd"
  }
}


resource "kubectl_manifest" "nfd" {
  depends_on = [
    module.cluster,
    kubernetes_namespace.nfd,
    null_resource.wait-for-gpu-operator,
    null_resource.wait-for-nfd-subscription
  ]

  yaml_body = <<YAML
apiVersion: "nfd.openshift.io/v1"
kind: "NodeFeatureDiscovery"
metadata:
  name: "nfd-instance"
  namespace: ${local.nfd_namespace}

spec:
  customConfig:
    configData: |
      #    - name: "more.kernel.features"
      #      matchOn:
      #      - loadedKMod: ["example_kmod3"]
      #    - name: "more.features.by.nodename"
      #      value: customValue
      #      matchOn:

  operand:
    servicePort: 12000
    image: >-
      registry.redhat.io/openshift4/ose-node-feature-discovery@sha256:ab719c23e369c8e080180d720d3b6d355f536dada563667ee9cfd673a78426d5

  workerConfig:
    configData: |
      core:
        sleepInterval: 60s
      sources:
        pci:
          deviceClassWhiteList: ["0200", "03", "12"]
          deviceLabelFields: ["vendor"]
YAML

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/auth.sh ${var.label} ${local.resource_group_name}"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<CMD
    kubectl patch nodefeaturediscovery -n openshift-nfd nfd-instance -p '{"metadata":{"finalizers": []}}' --type=merge || true
    CMD
  }
}

resource "null_resource" "wait-for-node-feature-discovery" {
  depends_on = [
    module.cluster,
    kubectl_manifest.nfd
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
    command     = "${path.module}/wait-for-nfd.sh ${local.nfd_namespace} nfd-instance"
  }
}


resource "kubectl_manifest" "gpu-cluster-policy" {
  depends_on = [
    module.cluster,
    null_resource.wait-for-gpu-operator,
    null_resource.wait-for-node-feature-discovery,
    null_resource.wait-for-nfd-subscription,
    kubectl_manifest.nfd
  ]

  yaml_body = <<YAML
apiVersion: "nvidia.com/v1"
kind: "ClusterPolicy"
metadata:
  name: "gpu-cluster-policy"

spec:
  vgpuDeviceManager:
    config:
      default: default
    enabled: true
  migManager:
    enabled: true
  operator:
    defaultRuntime: crio
    initContainer: {}
    runtimeClass: nvidia
    use_ocp_driver_toolkit: true
  dcgm:
    enabled: true
  gfd:
    enabled: true
  dcgmExporter:
    config:
      name: ''
    enabled: true
    serviceMonitor:
      enabled: true
  driver:
    certConfig:
      name: ''
    enabled: true
    kernelModuleConfig:
      name: ''
    licensingConfig:
      configMapName: ''
      nlsEnabled: false
    repoConfig:
      configMapName: ''
    upgradePolicy:
      autoUpgrade: true
      drain:
        deleteEmptyDir: false
        enable: false
        force: false
        timeoutSeconds: 300
      maxParallelUpgrades: 1
      podDeletion:
        deleteEmptyDir: false
        force: false
        timeoutSeconds: 300
      waitForCompletion:
        timeoutSeconds: 0
    virtualTopology:
      config: ''
  devicePlugin:
    config:
      default: ''
      name: ''
    enabled: true
  mig:
    strategy: single
  sandboxDevicePlugin:
    enabled: true
  validator:
    plugin:
      env:
        - name: WITH_WORKLOAD
          value: 'true'
  nodeStatusExporter:
    enabled: true
  daemonsets:
    rollingUpdate:
      maxUnavailable: '1'
    updateStrategy: RollingUpdate
  sandboxWorkloads:
    defaultWorkload: container
    enabled: false
  vgpuManager:
    enabled: false
  vfioManager:
    enabled: true
  toolkit:
    enabled: true
    installDir: /usr/local/nvidia
YAML
}
