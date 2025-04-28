# VPC outputs
output "won_q_vpc_id" {
  description = "The ID of the WON Q ORDER VPC"
  value       = aws_vpc.won_q_vpc.id
}

output "pg_vpc_id" {
  description = "The ID of the PG VPC"
  value       = aws_vpc.pg_vpc.id
}

output "card_vpc_id" {
  description = "The ID of the Woori Card VPC"
  value       = aws_vpc.card_vpc.id
}

# Subnet outputs
output "won_q_public_subnet_ids" {
  description = "List of IDs of WON Q ORDER public subnets"
  value       = aws_subnet.won_q_public[*].id
}

output "won_q_private_subnet_ids" {
  description = "List of IDs of WON Q ORDER private subnets"
  value       = aws_subnet.won_q_private[*].id
}

output "pg_public_subnet_ids" {
  description = "List of IDs of PG public subnets"
  value       = aws_subnet.pg_public[*].id
}

output "pg_private_subnet_ids" {
  description = "List of IDs of PG private subnets"
  value       = aws_subnet.pg_private[*].id
}

output "card_public_subnet_ids" {
  description = "List of IDs of Woori Card public subnets"
  value       = aws_subnet.card_public[*].id
}

output "card_private_subnet_ids" {
  description = "List of IDs of Woori Card private subnets"
  value       = aws_subnet.card_private[*].id
}

# S3 bucket outputs
output "merchant_images_bucket_name" {
  description = "The name of the merchant images S3 bucket"
  value       = module.merchant_images_bucket.s3_bucket_id
}

output "merchant_images_bucket_domain_name" {
  description = "The domain name of the merchant images S3 bucket"
  value       = module.merchant_images_bucket.s3_bucket_bucket_regional_domain_name
}

output "merchant_images_bucket_website_endpoint" {
  description = "The website endpoint of the merchant images S3 bucket"
  value       = module.merchant_images_bucket.s3_bucket_website_endpoint
}
