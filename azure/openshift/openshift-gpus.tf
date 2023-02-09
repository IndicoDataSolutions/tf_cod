


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

resource "kubernetes_manifest" "gpu" {
  depends_on = [
    kubernetes_namespace.gpu
  ]

  manifest = {
    apiVersion = "operators.coreos.com/v1"
    kind       = "OperatorGroup"
    metadata = {
      name      = "nvidia-gpu-operator-group"
      namespace = local.nvidia_operator_namespace
    }

    spec = {
      targetNamespaces = [local.nvidia_operator_namespace]
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

resource "kubernetes_manifest" "gpu-operator-subscription" {
  depends_on = [
    kubernetes_namespace.gpu
  ]

  manifest = {
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "Subscription"
    metadata = {
      name      = "gpu-operator-certified"
      namespace = local.nvidia_operator_namespace
    }
    spec = {
      channel             = "${local.channel}"
      installPlanApproval = "Automatic"
      name                = "gpu-operator-certified"
      source              = "certified-operators"
      sourceNamespace     = "openshift-marketplace"
      startingCSV         = "${local.package}"
    }
  }
  # wait until ready
  wait {
    fields = {
      "status.conditions[0].type"   = "CatalogSourcesUnhealthy"
      "status.conditions[0].status" = "False"
    }
  }
}


resource "kubernetes_namespace" "nfd" {
  depends_on = [
    kubernetes_manifest.gpu-operator-subscription
  ]

  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = local.nfd_namespace
  }
}


resource "kubernetes_manifest" "nfd" {
  depends_on = [
    kubernetes_namespace.nfd
  ]

  manifest = {
    apiVersion = "operators.coreos.com/v1"
    kind       = "OperatorGroup"
    metadata = {
      generateName = "openshift-nfd-"
      name         = "openshift-nfd"
      namespace    = local.nfd_namespace
    }
  }
}


resource "kubernetes_manifest" "nfd-operator-subscription" {
  depends_on = [
    kubernetes_namespace.nfd
  ]

  manifest = {
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "Subscription"
    metadata = {
      name      = "nfd"
      namespace = local.nfd_namespace
    }
    spec = {
      channel             = "stable"
      installPlanApproval = "Automatic"
      name                = "nfd"
      source              = "redhat-operators"
      sourceNamespace     = "openshift-marketplace"
    }
  }
  # wait until ready
  wait {
    fields = {
      "status.conditions[0].type"   = "CatalogSourcesUnhealthy"
      "status.conditions[0].status" = "False"
    }
  }
}




