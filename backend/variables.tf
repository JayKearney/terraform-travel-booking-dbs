variable "project_name" {
  description = "Name of the project"
  default     = "TravelBookingAppDBS"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  default     = "TravelBookingApp-Reviews"
}
