#To DO:
# Install nfs server
# get ip of service
# install nfs driver with IP
# make nfs sc the default
# install pre-reqs etc.

resource "kubectl_manifest" "nfs_volume" {
  depends_on = [
    module.cluster
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

resource "kubectl_manifest" "nfs_server" {
  depends_on = [
    kubectl_manifest.nfs_volume
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
        image: ${var.image_registry}/k8s.gcr.io/volume-nfs:0.8
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
        resources:
          requests:
            cpu: 450m
            memory: 2Gi
      volumes:
      - name: storage
        persistentVolumeClaim:
            claimName: nfs-pvc
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
  depends_on = ["null_resource.get_nfs_server_ip"]
}


resource "null_resource" "get_nfs_server_ip" {
  count = var.on_prem_test == true ? 1 : 0
  depends_on = [
    module.cluster,
    kubectl_manifest.nfs_server_service
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
    command = "./kubectl get service nfs-service -o jsonpath='{.spec.clusterIP}' > ${path.module}/nfs_server_ip.txt"
  }

  provisioner "local-exec" {
    command = "./kubectl get pods --no-headers | grep nfs-server | awk '{print $1}'| xargs -I {} sh -c './kubectl exec {} -- sh -c \"mkdir -p /exports/nfs-storage\"'"
  }

}

resource "helm_release" "nfs-provider" {
  count      = var.on_prem_test == true ? 1 : 0
  name       = "nfs-subdir-external-provisioner"
  repository = var.ipa_repo
  chart      = "nfs-subdir-external-provisioner"
  version    = var.nfs_subdir_external_provisioner_version
  namespace  = "default"
  depends_on = [
    module.cluster,
    kubectl_manifest.nfs_server_service,
    data.local_file.nfs_ip
  ]

  # // prometheus URL
  # set {
  #   name  = "nfs-subdir-external-provisioner.nfs.server"
  #   value = data.local_file.nfs_ip[0].content
  # }

  values = [<<EOF
    nfs-subdir-external-provisioner:
      nfs:
        server: ${data.local_file.nfs_ip[0].content}
        path: /exports
      image:
        repository: ${var.image_registry}/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner
  EOF
  ]
}

resource "null_resource" "update_storage_class" {
  count = var.on_prem_test == true ? 1 : 0
  depends_on = [
    helm_release.nfs-provider
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