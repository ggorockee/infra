data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}


provider "helm" {
  kubernetes {
    host = module.eks.cluster_endpoint
    # 모듈 출력값: base64 인코딩된 CA 데이터
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
