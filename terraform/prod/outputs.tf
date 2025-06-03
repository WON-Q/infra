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
      subnet_id   = subnet
      subnet_az   = module.vpc.azs[i]
      route_table = module.vpc.private_route_table_ids[i]
      nat_gateway = module.vpc.natgw_ids[i]
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
