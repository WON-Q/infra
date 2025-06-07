# EKS 클러스터 및 노드 그룹 구성
# 3개 AZ에 걸친 고가용성 EKS 클러스터

# EKS 클러스터
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "wonq-cluster"
  cluster_version = "1.32" # AWS EKS 기본값 (2025년 6월 4일 기준)

  # IAM 역할 설정
  create_iam_role = false
  iam_role_arn    = module.eks_cluster_role.iam_role_arn

  # KMS 키 설정 - 클러스터 비밀 암호화에 사용
  create_kms_key                  = true
  kms_key_deletion_window_in_days = 7
  enable_kms_key_rotation         = true

  # eks_cluster_role을 KMS 키 사용자로 추가
  kms_key_users = [
    module.eks_cluster_role.iam_role_arn
  ]

  # 관리자 계정을 KMS 키 관리자로 추가
  kms_key_administrators = ["arn:aws:iam::701693993886:user/sw1_user2"]

  # 클러스터 암호화 설정
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # VPC 및 서브넷 설정
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # 클러스터 엔드포인트 설정 - 퍼블릭/프라이빗 모두 활성화
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # 클러스터 로깅 설정
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # 클러스터 생성자에게 관리자 권한 자동 부여 설정
  enable_cluster_creator_admin_permissions = true

  # EKS 노드 그룹 설정
  eks_managed_node_groups = {
    wonq_nodes = {
      name = "wonq-node-group"

      # 인스턴스 타입
      instance_types = ["t3.medium"]

      # 노드 개수 (최소 3, 최대 4)
      min_size     = 3
      max_size     = 4
      desired_size = 3

      # 디스크 크기 설정
      disk_size = 20

      # AMI 타입 설정 - EKS 최적화된 Amazon Linux 2 AMI 사용
      ami_type = "AL2_x86_64"

      # 프라이빗 서브넷에 노드 배치
      subnet_ids = module.vpc.private_subnets

      # IAM 역할 설정 - 모듈로 생성한 노드 역할 사용
      create_iam_role = false
      iam_role_arn    = module.eks_node_role.iam_role_arn

      # 태그 설정
      tags = {
        Environment = "prod"
        Terraform   = "true"
        NodeGroup   = "wonq-nodes"
      }
    }
  }

  # EKS 클러스터 태그
  tags = {
    Environment = "prod"
    Terraform   = "true"
    Cluster     = "wonq-cluster"
  }
}
