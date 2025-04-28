# IAM User for S3 management
resource "aws_iam_user" "s3_manager" {
  name = "won-q-s3-manager"
  path = "/"

  tags = {
    Name    = "won-q-s3-manager"
    Service = "WON Q ORDER"
  }
}

# S3 bucket access policy
resource "aws_iam_policy" "s3_access_policy" {
  name        = "won-q-s3-access-policy"
  description = "Policy for uploading and deleting objects in the merchant images S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.merchant_images_bucket_name}"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.merchant_images_bucket_name}/*"
      }
    ]
  })
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "s3_manager_attach" {
  user       = aws_iam_user.s3_manager.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Generate access keys for the user
resource "aws_iam_access_key" "s3_manager_key" {
  user = aws_iam_user.s3_manager.name
}
