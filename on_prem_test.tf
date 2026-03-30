# To do:
# - [ ] Setup hostpath storage class
# - [ ] Create Hostpath PVs to support 2 crunchy instances
# - [ ] Install NFS server
# - [ ] Get IP of service
# - [ ] Install NFS driver with IP
# - [ ] Make NFS SC the default
# - [ ] Install pre-reqs etc.

locals {
  postgres_data_pv_spec_nfs = {
    storageClassName = "nfs-client"
    capacity         = { storage = var.postgres_volume_size }
    accessModes      = ["ReadWriteOnce"]
  }
  postgres_data_pgha1_pv_spec = var.on_prem_volume_backing == "local" ? {
    storageClassName = "local-storage"
    capacity         = { storage = var.postgres_volume_size }
    accessModes      = ["ReadWriteOnce"]
    hostPath         = { path = "/mnt/postgres-data" }
  } : local.postgres_data_pv_spec_nfs
  postgres_data_pgha2_pv_spec = var.on_prem_volume_backing == "local" ? {
    storageClassName = "local-storage"
    capacity         = { storage = var.postgres_volume_size }
    accessModes      = ["ReadWriteOnce"]
    hostPath         = { path = "/mnt/postgres-data" }
  } : local.postgres_data_pv_spec_nfs
}

resource "kubectl_manifest" "hostpath_storage_class" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster
  ]
  count     = var.on_prem_test == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
YAML
}


resource "kubectl_manifest" "postgres_data_pgha1_pv" {
  depends_on = concat(
    [
      module.cluster,
      time_sleep.wait_1_minutes_after_cluster
    ],
    var.on_prem_volume_backing == "local" ? [kubectl_manifest.hostpath_storage_class] : []
  )
  count = var.on_prem_test == true ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "PersistentVolume"
    metadata   = { name = "postgres-data-pgha1" }
    spec       = local.postgres_data_pgha1_pv_spec
  })
}

resource "kubectl_manifest" "postgres_data_pgha2_pv" {
  depends_on = concat(
    [
      module.cluster,
      time_sleep.wait_1_minutes_after_cluster
    ],
    var.on_prem_volume_backing == "local" ? [kubectl_manifest.hostpath_storage_class] : []
  )
  count = var.on_prem_test == true ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "PersistentVolume"
    metadata   = { name = "postgres-data-pgha2" }
    spec       = local.postgres_data_pgha2_pv_spec
  })
}

resource "kubectl_manifest" "nfs_volume" {
  depends_on = [
    module.cluster,
    time_sleep.wait_1_minutes_after_cluster,
    kubectl_manifest.postgres_data_pgha1_pv,
    kubectl_manifest.postgres_data_pgha2_pv
  ]
  count     = var.on_prem_test == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1000Gi
YAML
}
resource "kubectl_manifest" "nfs_server_conf" {
  depends_on = [
    kubectl_manifest.nfs_volume
  ]
  count     = var.on_prem_test == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: nfs-server-conf
data:
  share : |-
    /exports *(rw,fsid=0,insecure,no_root_squash)
YAML
}
resource "kubectl_manifest" "nfs_server" {
  depends_on = [
    kubectl_manifest.nfs_volume,
    kubectl_manifest.nfs_server_conf
  ]
  count     = var.on_prem_test == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-server
spec:
  selector:
    matchLabels:
      app: nfs-server
  template:
    metadata:
      labels:
        app: nfs-server
    spec:
      containers:
      - name: nfs-server
        image: ${var.image_registry}/indico/volume-nfs:test3
        ports:
        - name: nfs
          containerPort: 2049
        - name: mountd
          containerPort: 20048
        - name: rpcbind
          containerPort: 111
        securityContext:
          privileged: true
        volumeMounts:
        - name: storage
          mountPath: /exports
        - name: nfs-server-conf
          mountPath: /etc/exports.d/
        resources:
          requests:
            cpu: 450m
            memory: 2Gi
      volumes:
      - name: storage
        persistentVolumeClaim:
            claimName: nfs-pvc
      - name: nfs-server-conf
        configMap:
          name: nfs-server-conf
      imagePullSecrets:
      - name: harbor-pull-secret
YAML
}
resource "kubectl_manifest" "nfs_server_service" {
  depends_on = [
    kubectl_manifest.nfs_server
  ]
  count     = var.on_prem_test == true ? 1 : 0
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: nfs-service
spec:
  ports:
  - name: nfs
    port: 2049
  - name: mountd
    port: 20048
  - name: rpcbind
    port: 111
  selector:
    app: nfs-server # must match with the label of NFS pod
YAML
}


data "local_file" "nfs_ip" {
  count      = var.on_prem_test == true ? 1 : 0
  filename   = "${path.module}/nfs_server_ip.txt"
  depends_on = [null_resource.get_nfs_server_ip]
}


resource "null_resource" "get_nfs_server_ip" {
  count = var.on_prem_test == true ? 1 : 0
  depends_on = [
    module.cluster,
    kubectl_manifest.nfs_server_service,
    time_sleep.wait_1_minutes_after_cluster
  ]

  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl"
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.label} --region ${var.region}"
  }

  provisioner "local-exec" {
    command = "pwd && ls -lah"
  }

  provisioner "local-exec" {
    command = "./kubectl -n default get service nfs-service -o jsonpath='{.spec.clusterIP}' > ${path.module}/nfs_server_ip.txt"
  }

  provisioner "local-exec" {
    command = "./kubectl -n default get pods --no-headers | grep nfs-server | awk '{print $1}'| xargs -I {} sh -c './kubectl -n default exec {} -- sh -c \"mkdir -p /exports/nfs-storage\"'"
  }

}

resource "helm_release" "nfs-provider" {
  count      = var.on_prem_test == true ? 1 : 0
  name       = "csi-driver-nfs"
  repository = var.use_local_helm_charts ? null : var.ipa_repo
  chart      = var.use_local_helm_charts ? "./charts/csi-driver-nfs/" : "csi-driver-nfs"
  version    = var.use_local_helm_charts ? null : var.csi_driver_nfs_version
  max_history      = 10
  namespace  = "default"
  depends_on = [
    module.cluster,
    kubectl_manifest.nfs_server_service,
    time_sleep.wait_1_minutes_after_cluster
  ]

  # // prometheus URL
  # set {
  #   name  = "nfs-subdir-external-provisioner.nfs.server"
  #   value = data.local_file.nfs_ip[0].content
  # }

  values = [<<EOF
  feature:
    enableFSGroupPolicy: true
  image:
    baseRepo: ${var.image_registry}
  storageClass:
    create: true
    name: nfs-client
    parameters:
      server: nfs-service.default.svc.cluster.local
      share: /nfs-storage
  EOF
  ]
}

resource "null_resource" "update_storage_class" {
  count = var.on_prem_test == true ? 1 : 0
  depends_on = [
    helm_release.nfs-provider,
    null_resource.get_nfs_server_ip
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "./kubectl patch storageclass gp2 -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"false\"}}}'"
  }

  provisioner "local-exec" {
    command = "./kubectl patch storageclass nfs-client -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
  }
}
