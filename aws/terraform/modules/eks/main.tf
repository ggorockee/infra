module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name                    = "ggorockee-eks-cluster"
  cluster_version                 = "1.32"
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  authentication_mode = "API"

  access_entries = {
    # 1) 클러스터 관리자 권한을 줄 IAM 유저/롤
    cluster_admin = {
      principal_arn = "arn:aws:iam::329599650491:user/ggorockee_saa_03"

      policy_associations = {
        # 임의 이름
        admin_policy = {
          # EKS가 제공하는 클러스터 전체 관리 정책
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            # 클러스터 전체 범위 지정
            type       = "cluster"
            # namespaces = []  # 클러스터 범위면 생략 가능
          }
        }
      }
    }

    # 2) 노드 그룹 EC2 인스턴스에 자동으로 부여할 엔트리 (EKS가 관리하는 노드 그룹 역할)
    managed_node_role = {
      # 모듈 출력값에서 IAM 롤 ARN 참조
      principal_arn = module.eks.eks_managed_node_groups["default"].iam_role_arn
      # EC2 Linux 타입 지정 (IAM 역할 → 노드 자격)
      type          = "EC2_LINUX"
      # policy_associations 생략 시, EKS 기본 정책이 자동으로 연결됨
    }
  }
  
  

  # EKS Addons
  cluster_addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  create_kms_key              = false
  cluster_encryption_config   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2_x86_64"
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.micro"]

      subnet_ids = local.subnet_ids
      disk_size  = 20

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      create_iam_role          = true
      iam_role_name            = "ggorock-test-eks-managed-node-group"
      iam_role_use_name_prefix = false
      iam_role_description     = "EKS test managed node group"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }

      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        additional                         = aws_iam_policy.node_additional.arn
      }
    }
  }

  tags = local.tags
}
