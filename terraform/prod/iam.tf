# IAM 설정
# 개발자 그룹 및 권한 관리

# ---------- AWS sw1 그룹 정보 가져오기 (프로젝트 계정 제공받으며 이미 존재하는 그룹) ----------
data "aws_iam_group" "sw1" {
  group_name = "sw1"
}

# ---------- 개발자 그룹 -------------
resource "aws_iam_group" "wonq_developer" {
  name = "wonq-developer"
  path = "/"
}

# 개발자 그룹에 AWS 관리형 ReadOnlyAccess 정책 연결
resource "aws_iam_group_policy_attachment" "developer_readonly" {
  group      = aws_iam_group.wonq_developer.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# wonq-image-bucket에 대한 커스텀 S3 정책 생성
resource "aws_iam_policy" "wonq_s3_policy" {
  name        = "wonq-s3-policy"
  path        = "/"
  description = "Policy for WONQ S3 bucket access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::wonq-image-bucket"
      },
      {
        Sid    = "ObjectOperations"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::wonq-image-bucket/*"
      }
    ]
  })

  tags = {
    Name        = "wonq-s3-policy"
    Environment = "prod"
    Terraform   = "true"
  }
}

# 개발자 그룹에 wonq S3 버킷 정책 연결
resource "aws_iam_group_policy_attachment" "developer_s3_wonq" {
  group      = aws_iam_group.wonq_developer.name
  policy_arn = aws_iam_policy.wonq_s3_policy.arn
}

# 개발자 그룹에 AWS 관리형 IAMUserChangePassword 정책 연결
resource "aws_iam_group_policy_attachment" "developer_change_password" {
  group      = aws_iam_group.wonq_developer.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

# ---------- 관리자 그룹 ----------
resource "aws_iam_group" "wonq_administrator" {
  name = "wonq-administrator"
  path = "/"
}

# 관리자 그룹에 AWS 관리형 AdministratorAccess 정책 연결
resource "aws_iam_group_policy_attachment" "administrator_full_access" {
  group      = aws_iam_group.wonq_administrator.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 관리자 그룹에 AWS 관리형 IAMUserChangePassword 정책 연결
resource "aws_iam_group_policy_attachment" "administrator_change_password" {
  group      = aws_iam_group.wonq_administrator.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

# ---------- 기존 사용자들을 개발자 그룹에 추가 ----------
# 김새봄 - sw1_user1 (wonq-developer 그룹만)
resource "aws_iam_user_group_membership" "kim_saebom" {
  user = "sw1_user1"
  groups = [
    aws_iam_group.wonq_developer.name,
  ]
}

# 남승현 - sw1_user2 (wonq-administrator와 wonq-developer 그룹 모두)
resource "aws_iam_user_group_membership" "nam_seunghyeon" {
  user = "sw1_user2"
  groups = [
    aws_iam_group.wonq_administrator.name,
    aws_iam_group.wonq_developer.name,
  ]
}

# 신희원 - sw1_user3 (wonq-developer 그룹만)
resource "aws_iam_user_group_membership" "shin_heewon" {
  user = "sw1_user3"
  groups = [
    aws_iam_group.wonq_developer.name,
  ]
}

# 윤태경 - sw1_user4 (wonq-developer 그룹만)
resource "aws_iam_user_group_membership" "yoon_taekyeong" {
  user = "sw1_user4"
  groups = [
    aws_iam_group.wonq_developer.name,
  ]
}

# 황유환 - sw1_user5 (wonq-developer 그룹만)
resource "aws_iam_user_group_membership" "hwang_yuhwan" {
  user = "sw1_user5"
  groups = [
    aws_iam_group.wonq_developer.name,
  ]
}

# ---------- CI/CD 파이프라인 사용자와 정책 ----------
# GitHub Actions에서 사용할 IAM 사용자
resource "aws_iam_user" "wonq_cicd" {
  name = "wonq-cicd"
  path = "/"
}

# CI/CD 사용자에 AWS 관리형 AmazonEC2ContainerRegistryFullAccess 정책 연결
resource "aws_iam_user_policy_attachment" "wonq_cicd_ecr_attach" {
  user       = aws_iam_user.wonq_cicd.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# ---------- EKS 클러스터 IAM 역할 및 정책 ----------
module "eks_cluster_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.30.0"

  create_role = true
  role_name   = "wonq-eks-cluster-role"

  # EKS 서비스만 이 역할을 수임할 수 있도록 설정
  trusted_role_services = ["eks.amazonaws.com"]

  # MFA 조건 완전 비활성화 (EKS 서비스가 역할을 assume할 수 있도록)
  role_requires_mfa = false

  # EKS 클러스터에 필요한 권장 정책 연결
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy",
    "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser",
  ]
  number_of_custom_role_policy_arns = 6

  tags = {
    Name        = "wonq-eks-cluster-role"
    Environment = "prod"
    Terraform   = "true"
  }
}

# ---------- EKS 노드 그룹 IAM 역할 ----------
module "eks_node_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.30.0"

  create_role = true
  role_name   = "wonq-eks-node-role"

  # EC2 서비스만 이 역할을 수임할 수 있도록 설정 (EKS 노드는 EC2 인스턴스로 실행됨)
  trusted_role_services = ["ec2.amazonaws.com"]

  # MFA 조건 완전 비활성화 (EC2 서비스가 역할을 assume할 수 있도록)
  role_requires_mfa = false

  # EKS 노드에 필요한 권장 최소 정책 연결
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
  number_of_custom_role_policy_arns = 3

  tags = {
    Name        = "wonq-eks-node-role"
    Environment = "prod"
    Terraform   = "true"
  }
}
