


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
    module.cluster,
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

resource "kubernetes_manifest" "gpu-operator-subscription" {
  depends_on = [
    kubernetes_namespace.gpu,
    module.cluster
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
    module.cluster,
    kubernetes_manifest.gpu-operator-subscription
  ]

  metadata {
    labels = {
      "indico.io/openshift" = "true"
    }
    name = local.nfd_namespace
  }
}


resource "kubernetes_manifest" "nfd-operator" {
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

resource "kubernetes_manifest" "nfd-subscription" {
  depends_on = [
    kubernetes_manifest.nfd-operator
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

resource "kubernetes_manifest" "nfd" {
  depends_on = [
    kubernetes_manifest.nfd-subscription
  ]

  manifest = {
    apiVersion = "nfd.openshift.io/v1"
    kind       = "NodeFeatureDiscovery"
    metadata = {
      name      = "nfd-instance"
      namespace = local.nfd_namespace
    }
    spec = {
      customConfig = {
        configData = <<EOF
#    - name: "more.kernel.features"
#      matchOn:
#      - loadedKMod: ["example_kmod3"]
#    - name: "more.features.by.nodename"
#      value: customValue
#      matchOn:
#      - nodename: ["special-.*-node-.*"]
EOF
      }

      operand = {
        servicePort = 12000
        image       = "registry.redhat.io/openshift4/ose-node-feature-discovery@sha256:07658ef3df4b264b02396e67af813a52ba416b47ab6e1d2d08025a350ccd2b7b"
      }

      workerConfig = {
        configData = <<EOF
core:
  sleepInterval: 60s
sources:
  pci:
    deviceClassWhiteList: ["0200", "03", "12"]
    deviceLabelFields: ["vendor"]
EOF
      }
    }
  }

  wait {
    fields = {
      "status.conditions[0].type"   = "Available"
      "status.conditions[0].status" = "True"
    }
  }
}


resource "kubernetes_manifest" "gpu-cluster-policy" {
  depends_on = [
    kubernetes_manifest.nfd
  ]

  manifest = {
    apiVersion = "nvidia.com/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "gpu-cluster-policy"
    }

    spec = {
      vgpuDeviceManager = {
        config = {
          default = "default"
        }
        enabled = true
      }
      migManager = {
        enabled = true
      }
      operator = {
        defaultRuntime         = "crio"
        initContainer          = {}
        runtimeClass           = "nvidia"
        use_ocp_driver_toolkit = true
      }
      dcgm = {
        enabled = true
      }
      gfd = {
        enabled = true
      }
      dcgmExporter = {
        config = {
          name = ""
        }
        serviceMonitor = {
          enabled = true
        }
        enabled = true
      }
      driver = {
        enabled = true
        licensingConfig = {
          nlsEnabled    = false
          configMapName = ""
        }
        certConfig = {
          name = ""
        }
        kernelModuleConfig = {
          name = ""
        }
        upgradePolicy = {
          autoUpgrade = true
          drain = {
            deleteEmptyDir = false
            enable         = false
            force          = false
            timeoutSeconds = 300
          }
          maxParallelUpgrades = 1
          podDeletion = {
            deleteEmptyDir = false
            force          = false
            timeoutSeconds = 300
          }
          waitForCompletion = {
            timeoutSeconds = 0
          }
        }
        repoConfig = {
          configMapName = ""
        }
        virtualTopology = {
          config = ""
        }
      }
      devicePlugin = {
        enabled = true
      }
      mig = {
        strategy = "single"
      }
      validator = {
        plugin = {
          env = [
            {
              name  = "WITH_WORKLOAD"
              value = "true"
            }
          ]
        }
      }
      nodeStatusExporter = {
        enabled = true
      }
      daemonsets = {}
      toolkit = {
        enabled = true
      }
    }
  }
}
