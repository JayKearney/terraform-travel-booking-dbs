provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"
}

terraform {
  backend "s3" {
    bucket = "terraform-dbs-bucket"
    key    = "root/terraform.tfstate"
    region = "us-east-1"
  }
}

# Import Frontend State
data "terraform_remote_state" "frontend" {
  backend = "s3"
  config = {
    bucket = "terraform-dbs-bucket"
    key    = "frontend/terraform.tfstate"
    region = "us-east-1"
  }
}

# Import Backend State
data "terraform_remote_state" "backend" {
  backend = "s3"
  config = {
    bucket = "terraform-dbs-bucket"
    key    = "backend/terraform.tfstate"
    region = "us-east-1"
  }
}

# Import DynamoDB State
data "terraform_remote_state" "dynamodb" {
  backend = "s3"
  config = {
    bucket = "terraform-dbs-bucket"
    key    = "dynamodb/terraform.tfstate"
    region = "us-east-1"
  }
}

# Import IAM State
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "terraform-dbs-bucket"
    key    = "iam/terraform.tfstate"
    region = "us-east-1"
  }
}

# Outputs
output "frontend_url" {
  description = "URL of the CloudFront distribution for the frontend"
  value       = data.terraform_remote_state.frontend.outputs.cloudfront_url
}

output "backend_api_url" {
  description = "URL of the API Gateway for the backend"
  value       = data.terraform_remote_state.backend.outputs.api_gateway_url
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = data.terraform_remote_state.dynamodb.outputs.table_name
}

output "iam_user_arn" {
  description = "ARN of the IAM user"
  value       = data.terraform_remote_state.iam.outputs.user_arn
}
