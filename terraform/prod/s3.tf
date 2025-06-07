# S3 버킷 설정
# wonq-image-bucket 이미지 저장소 생성

module "wonq_image_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "wonq-image-bucket"
  acl    = "public-read" # 공개 읽기 접근 허용

  # 객체 소유권 설정
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  # 외부에서 이미지 접근 허용을 위한 설정
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # 버킷 정책 설정 - 이미지에 대한 공개 읽기 접근 허용
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::wonq-image-bucket/*"
      }
    ]
  })

  # 웹사이트 설정 활성화 - 이미지를 URL로 직접 접근 가능하게 함
  website = {
    index_document = "index.html"
    error_document = "error.html"
  }

  # CORS 설정 - 다양한 도메인에서의 이미지 접근 허용
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      expose_headers  = []
      max_age_seconds = 3000
    }
  ]

  # 버전 관리 비활성화 (이미지 저장소에서는 일반적으로 불필요)
  versioning = {
    enabled = false
  }

  # 태그 추가
  tags = {
    Name        = "wonq-image-bucket"
    Environment = "prod"
    Terraform   = "true"
  }
}
