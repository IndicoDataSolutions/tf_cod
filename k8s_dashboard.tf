



resource "helm_release" "k8s-dashboard" {
  depends_on = [
    module.cluster,
    helm_release.ipa-crds
  ]
  count            = var.enable_k8s_dashboard == true ? 1 : 0
  name             = "k8s"
  create_namespace = true
  namespace        = "default"
  repository       = var.ipa_repo
  chart            = "k8s-dashboard"
  version          = var.k8s_dashboard_chart_version

  values = [
    <<EOF
kubernetes-dashboard:
  extraArgs:
  - --enable-insecure-login
  - --system-banner="Viewing ${local.dns_name}"
  - --token-ttl=43200
  - --enable-skip-login

  # we are proxying
  protocolHttp: true

  settings:
    clusterName: "${local.dns_name}"
    itemsPerPage: 40
    logsAutoRefreshTimeInterval: 5
    resourceAutoRefreshTimeInterval: 5
    disableAccessDeniedNotifications: false

oauth2-proxy:
  extraArgs:
    insecure-oidc-allow-unverified-email: true
    email-domain: indico.io

  redis:
    enabled: true

  sessionStorage:
    type: redis

  # important
  extraEnv:
    - name: OAUTH2_PROXY_OIDC_ISSUER_URL
      value: https://keycloak.devops.indico.io/auth/realms/GoogleAuth
    - name: OAUTH2_PROXY_REDIRECT_URL
      value: https://k8s.${local.dns_name}/oauth2/callback
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
    clientID: ${keycloak_openid_client.k8s-keycloak-client.client_id}
    clientSecret: ${keycloak_openid_client.k8s-keycloak-client.client_secret}

  service:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: k8s.${local.dns_name}

  ingress:
    enabled: true
    hosts:
      - k8s.${local.dns_name}
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: zerossl
    tls:
      - hosts:
          - k8s.${local.dns_name}
        secretName: k8s-proxy-tls

   EOF
  ]
}

