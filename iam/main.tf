provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"
}

terraform {
  backend "s3" {
    bucket = "terraform-dbs-bucket"
    key    = "iam/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = "production"
  }
}

# Policy: DynamoDB Access
resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["dynamodb:*"],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"
      }
    ]
  })
}

# Policy: CloudWatch Logs Access
resource "aws_iam_policy" "lambda_logging" {
  name = "${var.project_name}-lambda-logging"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach policies to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# S3 Access Policy for Terraform User
resource "aws_iam_policy" "terraform_s3_access" {
  name = "${var.project_name}-terraform-s3-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::travelbookingapp-frontend",
          "arn:aws:s3:::travelbookingapp-frontend/*"
        ]
      }
    ]
  })
}

# Attach to terraform-user
resource "aws_iam_user_policy_attachment" "terraform_user_s3" {
  user       = "terraform-user"
  policy_arn = aws_iam_policy.terraform_s3_access.arn
}

# Outputs
output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

