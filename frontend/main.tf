provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"
}

terraform {
  backend "s3" {
    bucket = "terraform-dbs-bucket"
    key    = "frontend/terraform.tfstate"
    region = "us-east-1"
  }
}

# Reference the existing shared bucket
data "aws_s3_bucket" "frontend_bucket" {
  bucket = "terraform-dbs-bucket"
}

# Reference existing CloudFront distribution instead of creating a new one
data "aws_cloudfront_distribution" "existing" {
  id = "E3MINUOJ3MNLEJ"  # Your existing distribution ID
}

# Outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = data.aws_cloudfront_distribution.existing.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = data.aws_cloudfront_distribution.existing.domain_name
}

