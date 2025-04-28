# WON Q ORDER VPC 
resource "aws_vpc" "won_q_vpc" {
  cidr_block           = var.won_q_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "won-q-order-vpc"
    Service     = "WON Q ORDER"
  }
}

# PG Service VPC
resource "aws_vpc" "pg_vpc" {
  cidr_block           = var.pg_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "custom-pg-vpc"
    Service     = "Custom PG"
  }
}

# Woori Card VPC
resource "aws_vpc" "card_vpc" {
  cidr_block           = var.card_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "custom-card-vpc"
    Service     = "Custom Woori Card"
  }
}

# Internet Gateway for WON Q ORDER VPC
resource "aws_internet_gateway" "won_q_igw" {
  vpc_id = aws_vpc.won_q_vpc.id

  tags = {
    Name    = "${var.project_name}-won-q-igw"
    Service = "WON Q ORDER"
  }
}

# Internet Gateway for PG VPC
resource "aws_internet_gateway" "pg_igw" {
  vpc_id = aws_vpc.pg_vpc.id

  tags = {
    Name    = "${var.project_name}-pg-igw"
    Service = "Custom PG"
  }
}

# Internet Gateway for Card VPC
resource "aws_internet_gateway" "card_igw" {
  vpc_id = aws_vpc.card_vpc.id

  tags = {
    Name    = "${var.project_name}-card-igw"
    Service = "Custom Woori Card"
  }
}

# Route table for WON Q PUBLIC subnets
resource "aws_route_table" "won_q_public" {
  vpc_id = aws_vpc.won_q_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.won_q_igw.id
  }

  tags = {
    Name    = "${var.project_name}-won-q-public-rt"
    Service = "WON Q ORDER"
  }
}

# Route table for PG PUBLIC subnets
resource "aws_route_table" "pg_public" {
  vpc_id = aws_vpc.pg_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pg_igw.id
  }

  tags = {
    Name    = "${var.project_name}-pg-public-rt"
    Service = "Custom PG"
  }
}

# Route table for Card PUBLIC subnets
resource "aws_route_table" "card_public" {
  vpc_id = aws_vpc.card_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.card_igw.id
  }

  tags = {
    Name    = "${var.project_name}-card-public-rt"
    Service = "Custom Woori Card"
  }
}

# Public subnets for WON Q ORDER VPC
resource "aws_subnet" "won_q_public" {
  count                   = length(var.won_q_public_subnets)
  vpc_id                  = aws_vpc.won_q_vpc.id
  cidr_block              = var.won_q_public_subnets[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-won-q-public-${count.index + 1}"
    Service     = "WON Q ORDER"
  }
}

# Route table association for WON Q public subnets
resource "aws_route_table_association" "won_q_public" {
  count          = length(var.won_q_public_subnets)
  subnet_id      = aws_subnet.won_q_public[count.index].id
  route_table_id = aws_route_table.won_q_public.id
}

# Private subnets for WON Q ORDER VPC
resource "aws_subnet" "won_q_private" {
  count                   = length(var.won_q_private_subnets)
  vpc_id                  = aws_vpc.won_q_vpc.id
  cidr_block              = var.won_q_private_subnets[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-won-q-private-${count.index + 1}"
    Service     = "WON Q ORDER"
  }
}

# Public subnets for PG VPC
resource "aws_subnet" "pg_public" {
  count                   = length(var.pg_public_subnets)
  vpc_id                  = aws_vpc.pg_vpc.id
  cidr_block              = var.pg_public_subnets[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-pg-public-${count.index + 1}"
    Service     = "Custom PG"
  }
}

# Route table association for PG public subnets
resource "aws_route_table_association" "pg_public" {
  count          = length(var.pg_public_subnets)
  subnet_id      = aws_subnet.pg_public[count.index].id
  route_table_id = aws_route_table.pg_public.id
}

# Private subnets for PG VPC
resource "aws_subnet" "pg_private" {
  count                   = length(var.pg_private_subnets)
  vpc_id                  = aws_vpc.pg_vpc.id
  cidr_block              = var.pg_private_subnets[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-pg-private-${count.index + 1}"
    Service     = "Custom PG"
  }
}

# Public subnets for Card VPC
resource "aws_subnet" "card_public" {
  count                   = length(var.card_public_subnets)
  vpc_id                  = aws_vpc.card_vpc.id
  cidr_block              = var.card_public_subnets[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-card-public-${count.index + 1}"
    Service     = "Custom Woori Card"
  }
}

# Route table association for Card public subnets
resource "aws_route_table_association" "card_public" {
  count          = length(var.card_public_subnets)
  subnet_id      = aws_subnet.card_public[count.index].id
  route_table_id = aws_route_table.card_public.id
}

# Private subnets for Card VPC
resource "aws_subnet" "card_private" {
  count                   = length(var.card_private_subnets)
  vpc_id                  = aws_vpc.card_vpc.id
  cidr_block              = var.card_private_subnets[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-card-private-${count.index + 1}"
    Service     = "Custom Woori Card"
  }
}
