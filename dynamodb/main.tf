# Provider Configuration
provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"
}

# Backend configuration for DynamoDB state
terraform {
  backend "s3" {
    bucket = "terraform-dbs-bucket"
    key    = "dynamodb/terraform.tfstate"
    region = "us-east-1"
  }
}

# DynamoDB Table for Storing Reviews
resource "aws_dynamodb_table" "reviews_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"  # Serverless pricing
  hash_key     = "Id"

  attribute {
    name = "Id"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-dynamodb"
    Environment = "production"
  }
}

# Outputs
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.reviews_table.name
}
