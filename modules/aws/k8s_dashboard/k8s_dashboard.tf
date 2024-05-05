locals {
  ingress_values = var.use_static_ssl_certificates == false ? (<<EOT
oauth2-proxy:
  
  extraArgs:
    insecure-oidc-allow-unverified-email: true
    email-domain: indico.io

  redis:
    enabled: true
    replica:
      replicaCount: 1
    affinity:
      podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: redis
                    app.kubernetes.io/component: replica
                namespaces:
                  - "default"
                topologyKey: kubernetes.io/hostname
              weight: 1

  sessionStorage:
    type: redis

  # important
  extraEnv:
    - name: OAUTH2_PROXY_OIDC_ISSUER_URL
      value: https://keycloak.devops.indico.io/auth/realms/GoogleAuth
    - name: OAUTH2_PROXY_REDIRECT_URL
      value: https://k8s.${var.local_dns_name}/oauth2/callback
    - name: OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER
      value: 'true'
    - name: OAUTH2_PROXY_EMAIL_DOMAINS
      value: '*'
    - name: OAUTH2_PROXY_SKIP_PROVIDER_BUTTON
      value: 'true'
    - name: OAUTH2_PROXY_PROVIDER
      value: 'oidc'
    - name: OAUTH2_PROXY_ALLOWED_GROUPS
      value: DevOps,Engineering,QA,Customer Ops
    - name: OAUTH2_PROXY_UPSTREAMS
      value: http://k8s-kubernetes-dashboard:443
    - name: OAUTH2_PROXY_SSL_UPSTREAM_INSECURE_SKIP_VERIFY
      value: 'true'

  config:
    clientID: ${var.keycloak_client_id}
    clientSecret: ${var.keycloak_client_secret}
   

  service:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: k8s.${var.local_dns_name}  
  ingress:
    enabled: true
    hosts:
      - k8s.${var.local_dns_name}
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: zerossl
    tls:
      - hosts:
          - k8s.${var.local_dns_name}
        secretName: k8s-proxy-tls
  EOT
    ) : (<<EOT
oauth2-proxy:
  
  extraArgs:
    insecure-oidc-allow-unverified-email: true
    email-domain: indico.io

  redis:
    enabled: true
    replica:
      replicaCount: 1
    affinity:
      podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: redis
                    app.kubernetes.io/component: replica
                namespaces:
                  - "default"
                topologyKey: kubernetes.io/hostname
              weight: 1

  sessionStorage:
    type: redis

  # important
  extraEnv:
    - name: OAUTH2_PROXY_OIDC_ISSUER_URL
      value: https://keycloak.devops.indico.io/auth/realms/GoogleAuth
    - name: OAUTH2_PROXY_REDIRECT_URL
      value: https://k8s-${var.local_dns_name}/oauth2/callback
    - name: OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER
      value: 'true'
    - name: OAUTH2_PROXY_EMAIL_DOMAINS
      value: '*'
    - name: OAUTH2_PROXY_SKIP_PROVIDER_BUTTON
      value: 'true'
    - name: OAUTH2_PROXY_PROVIDER
      value: 'oidc'
    - name: OAUTH2_PROXY_ALLOWED_GROUPS
      value: DevOps,Engineering,QA,Customer Ops
    - name: OAUTH2_PROXY_UPSTREAMS
      value: http://k8s-kubernetes-dashboard:443
    - name: OAUTH2_PROXY_SSL_UPSTREAM_INSECURE_SKIP_VERIFY
      value: 'true'

  config:
    clientID: ${var.keycloak_client_id}
    clientSecret: ${var.keycloak_client_secret}
   

  service:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: k8s-${var.local_dns_name}
  ingress:
    enabled: true
    hosts:
      - k8s-${var.local_dns_name}
    annotations:
      kubernetes.io/ingress.class: nginx
    tls:
      - hosts:
          - k8s-${var.local_dns_name}
        secretName: ${var.ssl_static_secret_name}
EOT
  )
}

resource "helm_release" "k8s-dashboard" {
  name             = "k8s"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "k8s-dashboard"
  version          = var.k8s_dashboard_chart_version
  timeout          = 600   # 10 minutes
  wait             = false # don't bother to wait

  values = [
    <<EOF
kubernetes-dashboard:
  extraArgs:
  - --enable-insecure-login
  - --system-banner="Viewing ${var.local_dns_name}"
  - --token-ttl=43200
  - --enable-skip-login

  # we are proxying
  protocolHttp: true

  settings:
    clusterName: "${var.local_dns_name}"
    itemsPerPage: 40
    logsAutoRefreshTimeInterval: 5
    resourceAutoRefreshTimeInterval: 5
    disableAccessDeniedNotifications: false

${local.ingress_values}

   EOF
  ]
}
