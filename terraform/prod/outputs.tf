# VPC 정보 출력
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.igw_id
}

# 라우팅 테이블 정보
output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = module.vpc.private_route_table_ids
}

output "public_route_table_ids" {
  description = "Public route table IDs"
  value       = module.vpc.public_route_table_ids
}

# 가용영역별 매핑 정보
output "availability_zones" {
  description = "Availability zones used"
  value       = module.vpc.azs
}

# NAT Gateway와 Private Subnet 매핑 (크로스 AZ 연결 확인용)
output "nat_gateway_subnet_mapping" {
  description = "NAT Gateway to Private Subnet mapping for cross-AZ verification"
  value = {
    for i, subnet in module.vpc.private_subnets : "private-subnet-${i + 1}" => {
      subnet_id      = subnet
      subnet_az      = module.vpc.azs[i]
      route_table    = module.vpc.private_route_table_ids[i]
      nat_gateway    = module.vpc.natgw_ids[i]
      nat_gateway_az = module.vpc.azs[i]
    }
  }
}

# EIP 정보
output "nat_eip_ids" {
  description = "Elastic IP IDs for NAT Gateways"
  value       = aws_eip.nat[*].id
}

output "nat_eip_public_ips" {
  description = "Public IPs of NAT Gateway EIPs"
  value       = aws_eip.nat[*].public_ip
}

# S3 버킷 정보
output "wonq_image_bucket_id" {
  description = "이미지 버킷의 이름"
  value       = module.wonq_image_bucket.s3_bucket_id
}

output "wonq_image_bucket_arn" {
  description = "이미지 버킷의 ARN"
  value       = module.wonq_image_bucket.s3_bucket_arn
}

output "wonq_image_bucket_domain_name" {
  description = "이미지 버킷의 도메인 이름"
  value       = module.wonq_image_bucket.s3_bucket_bucket_domain_name
}

output "wonq_image_bucket_regional_domain_name" {
  description = "이미지 버킷의 리전별 도메인 이름"
  value       = module.wonq_image_bucket.s3_bucket_bucket_regional_domain_name
}

output "wonq_image_bucket_website_endpoint" {
  description = "이미지 버킷의 웹사이트 엔드포인트"
  value       = module.wonq_image_bucket.s3_bucket_website_endpoint
}

output "wonq_image_bucket_website_domain" {
  description = "이미지 버킷의 웹사이트 도메인"
  value       = module.wonq_image_bucket.s3_bucket_website_domain
}

# ECR 레포지토리 정보
output "ecr_repository_urls" {
  description = "ECR 레포지토리 URL 목록"
  value = {
    for name, repo in module.wonq_ecr : name => repo.repository_url
  }
}

output "ecr_repository_arns" {
  description = "ECR 레포지토리 ARN 목록"
  value = {
    for name, repo in module.wonq_ecr : name => repo.repository_arn
  }
}

# CI/CD 사용자 정보
output "cicd_user_arn" {
  description = "CI/CD 파이프라인에서 사용할 IAM 사용자 ARN"
  value       = aws_iam_user.wonq_cicd.arn
}

output "cicd_user_name" {
  description = "CI/CD 파이프라인에서 사용할 IAM 사용자 이름"
  value       = aws_iam_user.wonq_cicd.name
}

# ---------- RDS 데이터베이스 정보 ----------

# Main Database 정보
output "main_database_endpoint" {
  description = "Main 데이터베이스 엔드포인트"
  value       = module.main_database.db_instance_endpoint
}

output "main_database_identifier" {
  description = "Main 데이터베이스 식별자"
  value       = module.main_database.db_instance_identifier
}

output "main_database_arn" {
  description = "Main 데이터베이스 ARN"
  value       = module.main_database.db_instance_arn
}

output "main_database_port" {
  description = "Main 데이터베이스 포트"
  value       = module.main_database.db_instance_port
}

output "main_database_name" {
  description = "Main 데이터베이스 이름"
  value       = module.main_database.db_instance_name
}

output "main_database_username" {
  description = "Main 데이터베이스 사용자명"
  value       = module.main_database.db_instance_username
  sensitive   = true
}

output "main_database_password" {
  description = "Main 데이터베이스 비밀번호"
  value       = random_password.main_db_password.result
  sensitive   = true
}

# Batch Database 정보
output "batch_database_endpoint" {
  description = "Batch 데이터베이스 엔드포인트"
  value       = module.batch_database.db_instance_endpoint
}

output "batch_database_identifier" {
  description = "Batch 데이터베이스 식별자"
  value       = module.batch_database.db_instance_identifier
}

output "batch_database_arn" {
  description = "Batch 데이터베이스 ARN"
  value       = module.batch_database.db_instance_arn
}

output "batch_database_port" {
  description = "Batch 데이터베이스 포트"
  value       = module.batch_database.db_instance_port
}

output "batch_database_name" {
  description = "Batch 데이터베이스 이름"
  value       = module.batch_database.db_instance_name
}

output "batch_database_username" {
  description = "Batch 데이터베이스 사용자명"
  value       = module.batch_database.db_instance_username
  sensitive   = true
}

output "batch_database_password" {
  description = "Batch 데이터베이스 비밀번호"
  value       = random_password.batch_db_password.result
  sensitive   = true
}

# RDS 보안 그룹 정보
output "rds_security_group_id" {
  description = "RDS 보안 그룹 ID"
  value       = aws_security_group.rds_security_group.id
}

output "rds_security_group_arn" {
  description = "RDS 보안 그룹 ARN"
  value       = aws_security_group.rds_security_group.arn
}

# DB 서브넷 그룹 정보
output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = aws_db_subnet_group.wonq_db_subnet_group.name
}

output "db_subnet_group_arn" {
  description = "DB 서브넷 그룹 ARN"
  value       = aws_db_subnet_group.wonq_db_subnet_group.arn
}

# DB 파라미터 그룹 정보
output "db_parameter_group_name" {
  description = "DB 파라미터 그룹 이름"
  value       = aws_db_parameter_group.wonq_mysql_parameter_group.name
}

output "db_parameter_group_arn" {
  description = "DB 파라미터 그룹 ARN"
  value       = aws_db_parameter_group.wonq_mysql_parameter_group.arn
}
