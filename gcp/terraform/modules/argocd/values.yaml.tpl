global:
  domain: ${domain != "" ? domain : "argocd.local"}

configs:
  params:
    server.insecure: true

  cm:
    # Dex configuration for Google OAuth
    dex.config: |
      connectors:
        - type: google
          id: google
          name: Google
          config:
            clientID: $argocd-secrets:dex.google.clientId
            clientSecret: $argocd-secrets:dex.google.clientSecret
            redirectURI: https://${domain != "" ? domain : "argocd.local"}/api/dex/callback
            hostedDomains:
              - gmail.com

    # RBAC policy
    policy.csv: |
      g, woohaen88@gmail.com, role:admin
      g, woohalabs@gmail.com, role:admin
      g, ggorockee@gmail.com, role:admin

    # Admin enabled
    admin.enabled: "true"

  # secret 설정 제거 - Helm이 기본 argocd-secret 생성
  # admin password는 초기화 Job에서 업데이트

server:
  service:
    type: ClusterIP  # Changed from LoadBalancer to integrate with Istio Ingress Gateway

  extraArgs:
    - --insecure  # TLS termination handled by Istio Gateway

  # Workload Identity annotation
  serviceAccount:
    create: true
    name: argocd-server
    annotations:
      iam.gke.io/gcp-service-account: argocd-${environment}@${project_id}.iam.gserviceaccount.com

repoServer:
  replicas: 1

applicationSet:
  enabled: true
  replicas: 1

notifications:
  enabled: false

dex:
  enabled: true

redis:
  enabled: true
