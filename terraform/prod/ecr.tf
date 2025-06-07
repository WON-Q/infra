# ECR 레포지토리 설정
# 서비스 도커 이미지 저장소 생성

module "wonq_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  for_each = toset([
    "app-card-server",
    "bank-server",
    "card-server",
    "pg-client",
    "pg-server",
    "wonq-order-merchant-client",
    "wonq-order-server",
    "wonq-order-user-client",
  ])

  repository_name = each.key

  # 이미지 태그 변경 가능하도록 설정 (MUTABLE)
  repository_image_tag_mutability = "MUTABLE"

  # 이미지 푸시 시 자동 스캔 활성화
  repository_image_scan_on_push = true

  # 이미지 강제 삭제 허용 (태그가 있어도 삭제 가능)
  repository_force_delete = true

  # 생명주기 정책 - 이미지 관리
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "14일 이상 미사용된 untagged 이미지 제거",
        selection = {
          tagStatus   = "untagged",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 14
        },
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2,
        description  = "이미지 최대 수 제한: 최신 100개만 유지",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = 100
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Name        = "wonq-ecr-${each.key}"
    Environment = "prod"
    Terraform   = "true"
  }
}
