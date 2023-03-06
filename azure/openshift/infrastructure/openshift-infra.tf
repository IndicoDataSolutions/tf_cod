
resource "helm_release" "indico-admission-controller" {
  depends_on = [
    time_sleep.wait_1_minutes_after_pre_reqs
  ]

  count = var.use_admission_controller == true ? 1 : 0

  name             = "adm"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "indico-openshift-adm"
  version          = var.openshift_admission_chart_version
  timeout          = "600" # 10 minutes
  wait             = true

}


resource "helm_release" "indico-admission-webhook" {
  depends_on = [
    time_sleep.wait_1_minutes_after_pre_reqs
  ]

  count = var.use_admission_controller == true ? 1 : 0

  name             = "wh"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "indico-openshift-webhook"
  version          = var.openshift_admission_chart_version
  wait             = true
}



resource "helm_release" "crunchy-postgres" {
  depends_on = [
    helm_release.indico-admission-controller,
    helm_release.indico-admission-webhook
  ]

  name             = "crunchy"
  create_namespace = true
  namespace        = var.ipa_namespace
  repository       = var.ipa_repo
  chart            = "crunchy-postgres"
  version          = "0.3.0"
  timeout          = "600" # 10 minutes
  wait             = true

  values = [<<EOF
  enabled: true
  postgres-data:
    openshift: true
    metadata:
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
        reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    instances:
    - affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node_group
                operator: In
                values:
                - pgo-workers
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: postgres-operator.crunchydata.com/cluster
                operator: In
                values:
                - postgres-data
              - key: postgres-operator.crunchydata.com/instance-set
                operator: In
                values:
                - pgha1
            topologyKey: kubernetes.io/hostname
      metadata:
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
      dataVolumeClaimSpec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 200Gi
      name: pgha1
      replicas: 1
      resources:
        requests:
          cpu: 500m
          memory: 3000Mi
      tolerations:
        - effect: NoSchedule
          key: indico.io/crunchy
          operator: Exists
    pgBackRestConfig:
      repos:
      - name: repo1
        volume:
          volumeClaimSpec:
            accessModes:
            - ReadWriteOnce
            resources:
              requests:
                storage: 200Gi
        schedules:
          full: 30 4 * * *
          incremental: 0 */1 * * *
    imagePullSecrets:
      - name: harbor-pull-secret
  postgres-metrics:
    enabled: false
  EOF
  ]
}


