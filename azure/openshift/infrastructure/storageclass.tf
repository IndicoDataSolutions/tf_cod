

resource "kubernetes_storage_class" "default" {
  metadata {
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
    name = "default"
    labels = {
      "addonmanager.kubernetes.io/mode" = "EnsureExists"
      "kubernetes.io/cluster-service"   = "true"
    }
  }
  allow_volume_expansion = true
  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    skuname = "StandardSSD_LRS"
  }
}
