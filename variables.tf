variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-2"  # Seoul region
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "won-q-order"
}

# VPC CIDR blocks
variable "won_q_vpc_cidr" {
  description = "CIDR for WON Q ORDER VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "pg_vpc_cidr" {
  description = "CIDR for Custom PG VPC"
  type        = string
  default     = "172.17.0.0/16"
}

variable "card_vpc_cidr" {
  description = "CIDR for Custom Woori Card VPC"
  type        = string
  default     = "172.18.0.0/16"
}

# Subnet configurations
variable "won_q_public_subnets" {
  description = "Public subnet CIDRs for WON Q ORDER VPC"
  type        = list(string)
  default     = ["172.16.1.0/24", "172.16.2.0/24"]
}

variable "won_q_private_subnets" {
  description = "Private subnet CIDRs for WON Q ORDER VPC"
  type        = list(string)
  default     = ["172.16.11.0/24", "172.16.12.0/24"]
}

variable "pg_public_subnets" {
  description = "Public subnet CIDRs for PG VPC"
  type        = list(string)
  default     = ["172.17.1.0/24", "172.17.2.0/24"]
}

variable "pg_private_subnets" {
  description = "Private subnet CIDRs for PG VPC"
  type        = list(string)
  default     = ["172.17.11.0/24", "172.17.12.0/24"]
}

variable "card_public_subnets" {
  description = "Public subnet CIDRs for Woori Card VPC"
  type        = list(string)
  default     = ["172.18.1.0/24", "172.18.2.0/24"]
}

variable "card_private_subnets" {
  description = "Private subnet CIDRs for Woori Card VPC"
  type        = list(string)
  default     = ["172.18.11.0/24", "172.18.12.0/24"]
}

# Availability Zones
variable "azs" {
  description = "Availability Zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# NAT Gateway configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

# S3 Bucket
variable "merchant_images_bucket_name" {
  description = "S3 bucket name for merchant images"
  type        = string
  default     = "won-q-order-merchant"
}
