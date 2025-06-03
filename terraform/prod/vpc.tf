# VPC 및 네트워크 구성
# 3개 AZ에 걸친 고가용성 VPC 구성

# EIP for NAT Gateways (각 AZ별로 고정 IP 할당)
resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"

  tags = {
    Name        = "wonq-nat-eip-${count.index + 1}"
    Environment = "prod"
    Terraform   = "true"
  }
}

# VPC 모듈
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "wonq-vpc"
  cidr = "10.0.0.0/16"

  # 3개 AZ 구성 (ap-northeast-2a, ap-northeast-2b, ap-northeast-2c)
  azs             = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]

  # NAT Gateway 고가용성 구성 (각 AZ별 배치)
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  reuse_nat_ips          = true
  external_nat_ip_ids    = aws_eip.nat[*].id

  # DNS 설정
  enable_dns_hostnames = true
  enable_dns_support   = true

  # 태그 설정
  tags = {
    Environment = "prod"
    Terraform   = "true"
  }

  # Public 서브넷 태그 및 이름
  public_subnet_tags = {
    Type = "public"
  }
  public_subnet_names = ["wonq-public1-subnet", "wonq-public2-subnet", "wonq-public3-subnet"]

  # Private 서브넷 태그 및 이름
  private_subnet_tags = {
    Type = "private"
  }
  private_subnet_names = ["wonq-private1-subnet", "wonq-private2-subnet", "wonq-private3-subnet"]

  # NAT Gateway 태그
  nat_gateway_tags = {
    Name        = "wonq-nat-gateway"
    Environment = "prod"
    Terraform   = "true"
  }

  # Private Route Table 태그
  private_route_table_tags = {
    Name = "wonq-private-route-table"
  }

  # Public Route Table 태그
  public_route_table_tags = {
    Name = "wonq-public-route-table"
  }

  # Default Route Table 태그
  default_route_table_tags = {
    Name = "wonq-default-route-table"
  }

  # Internet Gateway 태그
  igw_tags = {
    Name = "wonq-internet-gateway"
  }
}

# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.ap-northeast-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name        = "wonq-s3-vpc-endpoint"
    Environment = "prod"
    Terraform   = "true"
  }
}