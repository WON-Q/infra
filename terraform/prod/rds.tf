# RDS 데이터베이스 구성
# Main Database와 Batch Database 생성

# ---------- RDS 서브넷 그룹 ----------
# Private 서브넷을 사용하여 DB 서브넷 그룹 생성
resource "aws_db_subnet_group" "wonq_db_subnet_group" {
  name       = "wonq-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name        = "wonq-db-subnet-group"
    Environment = "prod"
    Terraform   = "true"
  }
}

# ---------- RDS 보안 그룹 ----------
# EKS 노드에서만 RDS에 접근할 수 있도록 설정
resource "aws_security_group" "rds_security_group" {
  name_prefix = "wonq-rds-sg"
  vpc_id      = module.vpc.vpc_id

  # MySQL/Aurora 포트 (3306)로 EKS 노드에서만 접근 허용
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
    description     = "Allow MySQL access from EKS nodes"
  }

  # 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "wonq-rds-security-group"
    Environment = "prod"
    Terraform   = "true"
  }
}

# ---------- 랜덤 비밀번호 생성 ----------
# Main Database용 랜덤 비밀번호
resource "random_password" "main_db_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Batch Database용 랜덤 비밀번호
resource "random_password" "batch_db_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# ---------- RDS 파라미터 그룹 ----------
# MySQL 8.0용 커스텀 파라미터 그룹 (한국 시간대 설정)
resource "aws_db_parameter_group" "wonq_mysql_parameter_group" {
  family = "mysql8.0"
  name   = "wonq-mysql80-parameter-group"

  parameter {
    name  = "time_zone"
    value = "Asia/Seoul"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Name        = "wonq-mysql80-parameter-group"
    Environment = "prod"
    Terraform   = "true"
  }
}

# ---------- Main Database ----------
module "main_database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "wonq-main-db"

  # 엔진 설정
  engine         = "mysql"
  engine_version = "8.0.41"
  instance_class = "db.t3.micro" # 최소 인스턴스 타입

  # 스토리지 설정
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  # 데이터베이스 설정
  db_name  = "wonq_main"
  username = "admin"

  # 랜덤 비밀번호 사용
  password = random_password.main_db_password.result

  # 포트 설정
  port = "3306"

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.wonq_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]

  # 단일 AZ 배포
  multi_az            = false
  availability_zone   = "ap-northeast-2a"
  publicly_accessible = false

  # 파라미터 그룹 설정
  create_db_parameter_group = false
  parameter_group_name      = aws_db_parameter_group.wonq_mysql_parameter_group.name

  # 옵션 그룹 설정 (MySQL 8.0에서는 기본값 사용)
  create_db_option_group = false

  # 백업 설정 - 일일정산 배치(02:00) 이후 백업 실행
  backup_retention_period  = 30            # 30일 백업 보존 (정산 데이터 보관 기간 고려)
  backup_window            = "04:00-05:00" # 일일정산 배치(02:00) 완료 후 백업
  maintenance_window       = "Sun:05:00-Sun:06:00"
  copy_tags_to_snapshot    = true  # 스냅샷에 태그 복사
  delete_automated_backups = false # 자동 백업 삭제 방지

  # 모니터링 설정
  monitoring_interval    = 60
  create_monitoring_role = true
  monitoring_role_name   = "wonq-main-db-monitoring-role"

  # 성능 인사이트 비활성화 (비용 절약)
  performance_insights_enabled = false

  # 로그 내보내기 설정
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  create_cloudwatch_log_group     = true

  # 삭제 보호 설정
  deletion_protection = false # 개발/테스트 환경에서는 false
  skip_final_snapshot = true

  # 자동 마이너 버전 업그레이드
  auto_minor_version_upgrade = true

  tags = {
    Name        = "wonq-main-database"
    Environment = "prod"
    Terraform   = "true"
    Database    = "main"
  }
}

# ---------- Batch Database ----------
module "batch_database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "wonq-batch-db"

  # 엔진 설정
  engine         = "mysql"
  engine_version = "8.0.41"
  instance_class = "db.t3.micro" # 최소 인스턴스 타입

  # 스토리지 설정
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  # 데이터베이스 설정
  db_name  = "wonq_batch"
  username = "admin"

  # 랜덤 비밀번호 사용
  password = random_password.batch_db_password.result

  # 포트 설정
  port = "3306"

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.wonq_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]

  # 단일 AZ 배포
  multi_az            = false
  availability_zone   = "ap-northeast-2b" # Main DB와 다른 AZ에 배치
  publicly_accessible = false

  # 파라미터 그룹 설정
  create_db_parameter_group = false
  parameter_group_name      = aws_db_parameter_group.wonq_mysql_parameter_group.name

  # 옵션 그룹 설정 (MySQL 8.0에서는 기본값 사용)
  create_db_option_group = false

  # 백업 설정 - Batch DB는 중간 데이터 처리용이므로 기본 백업
  backup_retention_period  = 14            # 2주 백업 보존 (배치 작업 히스토리 추적용)
  backup_window            = "05:30-06:30" # Main DB 백업 완료 후 진행
  maintenance_window       = "Sun:06:30-Sun:07:30"
  copy_tags_to_snapshot    = true  # 스냅샷에 태그 복사
  delete_automated_backups = false # 자동 백업 삭제 방지

  # 모니터링 설정
  monitoring_interval    = 60
  create_monitoring_role = true
  monitoring_role_name   = "wonq-batch-db-monitoring-role"

  # 성능 인사이트 비활성화 (비용 절약)
  performance_insights_enabled = false

  # 로그 내보내기 설정
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  create_cloudwatch_log_group     = true

  # 삭제 보호 설정
  deletion_protection = false # 개발/테스트 환경에서는 false
  skip_final_snapshot = true

  # 자동 마이너 버전 업그레이드
  auto_minor_version_upgrade = true

  tags = {
    Name        = "wonq-batch-database"
    Environment = "prod"
    Terraform   = "true"
    Database    = "batch"
  }
}
