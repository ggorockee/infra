resource "helm_release" "aws_vpc_cni" {
  count      = local.vpc_cni_helm_install ? 1 : 0
  name       = "aws-vpc-cni"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-vpc-cni"
  version    = "1.19.5"

  set {
    name  = "env.ENABLE_PREFIX_DELEGATION"
    value = "true"
  }
  set {
    name  = "env.WARM_PREFIX_TARGET"
    value = "1"
  }
  set {
    name  = "env.MAX_PODS"
    value = "32" # 2x(16-1) + 2
  }
}
