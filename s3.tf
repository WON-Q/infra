module "merchant_images_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${var.merchant_images_bucket_name}"
  
  # Enable public access for merchant images
  acl                 = "public-read"
  control_object_ownership = true
  object_ownership    = "ObjectWriter"
  
  # Allow website functionality for direct image access
  website = {
    index_document = "index.html" # Default landing page
    error_document = "error.html" # Error page
  }
  
  # Configure CORS for web access
  cors_rule = [
    {
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      allowed_headers = ["*"]
      expose_headers  = []
      max_age_seconds = 3000
    }
  ]
  
  # Public access settings
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  
  # Attach policy for public read access
  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${var.merchant_images_bucket_name}/*"
      }
    ]
  })
  
  # General settings
  force_destroy = false # Don't allow bucket deletion with content in prod
  
  tags = {
    Name        = "${var.merchant_images_bucket_name}"
    Service     = "WON Q ORDER"
    Managed     = "Terraform"
  }
}
