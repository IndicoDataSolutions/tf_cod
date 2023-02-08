

resource "kubernetes_namespace" "gpu" {
  depends_on = [
    module.cluster
  ]
  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = "nvidia-gpu-operator"
  }
}

resource "kubernetes_manifest" "gpu" {
  depends_on = [
    kubernetes_namespace.gpu
  ]

  manifest = {
    apiVersion = "operators.coreos.com/v1"
    kind       = "OperatorGroup"
    metadata = {
      name      = "nvidia-gpu-operator-group"
      namespace = "nvidia-gpu-operator"
    }
  }
}

data "kubernetes_resource" "package" {
  api_version = "packages.operators.coreos.com/v1"
  kind        = "PackageManifest"

  metadata {
    name      = "gpu-operator-certified"
    namespace = "openshift-marketplace"
  }
}

output "channel" {
  value = data.kubernetes_resource.package.object.status.defaultChannel
}


output "status" {
  value = data.kubernetes_resource.package.object.status
}

# PACKAGE=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')
output "package" {
  value = element([for c in data.kubernetes_resource.package.object.status.channels : c.currentCSV if c.name == data.kubernetes_resource.package.object.status.defaultChannel], 0)
}
