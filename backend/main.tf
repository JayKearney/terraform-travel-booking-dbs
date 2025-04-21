# Provider Configuration
provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"
}

terraform {
  backend "s3" {
    bucket = "terraform-dbs-bucket"
    key    = "backend/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "terraform-dbs-bucket"
    key    = "iam/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "dynamodb" {
  backend = "s3"
  config = {
    bucket = "terraform-dbs-bucket"
    key    = "dynamodb/terraform.tfstate"
    region = "us-east-1"
  }
}

# Lambda
resource "aws_lambda_function" "backend_lambda" {
  function_name    = "${var.project_name}-backend"
  role             = data.terraform_remote_state.iam.outputs.lambda_role_arn
  handler          = "TravelBookingApp"
  runtime          = "dotnet8"
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
  timeout          = 180
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = data.terraform_remote_state.dynamodb.outputs.dynamodb_table_name
    }
  }
}

# API Gateway setup
resource "aws_api_gateway_rest_api" "backend_api" {
  name        = "${var.project_name}-api"
  description = "API Gateway for the backend Lambda function"
}

# Review-related paths
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_rest_api.backend_api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "review_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.api_resource.id
  path_part   = "Review"
}

# Add GetReviews Resource
resource "aws_api_gateway_resource" "getreviews_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.review_resource.id
  path_part   = "GetReviews"
}

# GET method for GetReviews
resource "aws_api_gateway_method" "getreviews_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.getreviews_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "getreviews_integration" {
  rest_api_id             = aws_api_gateway_rest_api.backend_api.id
  resource_id             = aws_api_gateway_resource.getreviews_resource.id
  http_method             = aws_api_gateway_method.getreviews_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend_lambda.invoke_arn
}

# CORS OPTIONS for /Review/GetReviews
resource "aws_api_gateway_method" "getreviews_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.getreviews_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "getreviews_options_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.getreviews_resource.id
  http_method = aws_api_gateway_method.getreviews_options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "getreviews_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.getreviews_resource.id
  http_method = aws_api_gateway_method.getreviews_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_integration_response" "getreviews_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.getreviews_resource.id
  http_method = aws_api_gateway_method.getreviews_options_method.http_method
  status_code = aws_api_gateway_method_response.getreviews_options_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://d2qn627n6ccjjs.cloudfront.net'"
  }
}

# Add CORS headers to the GET method response
resource "aws_api_gateway_method_response" "getreviews_get_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.getreviews_resource.id
  http_method = aws_api_gateway_method.getreviews_method.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Add User Resource and Login endpoint
resource "aws_api_gateway_resource" "user_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.api_resource.id
  path_part   = "User"
}

resource "aws_api_gateway_resource" "login_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.user_resource.id
  path_part   = "Login"
}

# POST method for Login
resource "aws_api_gateway_method" "login_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.login_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "login_integration" {
  rest_api_id             = aws_api_gateway_rest_api.backend_api.id
  resource_id             = aws_api_gateway_resource.login_resource.id
  http_method             = aws_api_gateway_method.login_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend_lambda.invoke_arn
}

# CORS OPTIONS for /User/Login
resource "aws_api_gateway_method" "login_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.login_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "login_options_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.login_resource.id
  http_method = aws_api_gateway_method.login_options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "login_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.login_resource.id
  http_method = aws_api_gateway_method.login_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_integration_response" "login_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.login_resource.id
  http_method = aws_api_gateway_method.login_options_method.http_method
  status_code = aws_api_gateway_method_response.login_options_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://d2qn627n6ccjjs.cloudfront.net'"
  }
}

# Add CORS headers to the POST method response
resource "aws_api_gateway_method_response" "login_post_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.login_resource.id
  http_method = aws_api_gateway_method.login_method.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# AddReview resource
resource "aws_api_gateway_resource" "addreview_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.review_resource.id
  path_part   = "AddReview"
}

# POST method
resource "aws_api_gateway_method" "backend_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.addreview_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.backend_api.id
  resource_id             = aws_api_gateway_resource.addreview_resource.id
  http_method             = aws_api_gateway_method.backend_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend_lambda.invoke_arn
}

# CORS OPTIONS for /Review/AddReview
resource "aws_api_gateway_method" "addreview_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.addreview_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "addreview_options_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.addreview_resource.id
  http_method = aws_api_gateway_method.addreview_options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "addreview_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.addreview_resource.id
  http_method = aws_api_gateway_method.addreview_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_integration_response" "addreview_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.addreview_resource.id
  http_method = aws_api_gateway_method.addreview_options_method.http_method
  status_code = aws_api_gateway_method_response.addreview_options_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://d2qn627n6ccjjs.cloudfront.net'"
  }
}

# Add CORS headers to the POST method response
resource "aws_api_gateway_method_response" "addreview_post_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.addreview_resource.id
  http_method = aws_api_gateway_method.backend_method.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# DeleteReview resource with path parameter
resource "aws_api_gateway_resource" "deletereview_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.review_resource.id
  path_part   = "DeleteReview"
}

resource "aws_api_gateway_resource" "deletereview_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  parent_id   = aws_api_gateway_resource.deletereview_resource.id
  path_part   = "{id}"
}

# DELETE method
resource "aws_api_gateway_method" "deletereview_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.deletereview_id_resource.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "deletereview_integration" {
  rest_api_id             = aws_api_gateway_rest_api.backend_api.id
  resource_id             = aws_api_gateway_resource.deletereview_id_resource.id
  http_method             = aws_api_gateway_method.deletereview_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend_lambda.invoke_arn
}

# CORS OPTIONS for /Review/DeleteReview/{id}
resource "aws_api_gateway_method" "deletereview_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  resource_id   = aws_api_gateway_resource.deletereview_id_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "deletereview_options_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.deletereview_id_resource.id
  http_method = aws_api_gateway_method.deletereview_options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "deletereview_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.deletereview_id_resource.id
  http_method = aws_api_gateway_method.deletereview_options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_integration_response" "deletereview_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.deletereview_id_resource.id
  http_method = aws_api_gateway_method.deletereview_options_method.http_method
  status_code = aws_api_gateway_method_response.deletereview_options_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'https://d2qn627n6ccjjs.cloudfront.net'"
  }
}

# Add CORS headers to the DELETE method response
resource "aws_api_gateway_method_response" "deletereview_delete_response" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  resource_id = aws_api_gateway_resource.deletereview_id_resource.id
  http_method = aws_api_gateway_method.deletereview_method.http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Lambda permissions
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.backend_api.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "backend_deployment" {
  rest_api_id = aws_api_gateway_rest_api.backend_api.id
  
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.getreviews_integration,
    aws_api_gateway_integration.login_integration,
    aws_api_gateway_integration.deletereview_integration,
    aws_api_gateway_integration.addreview_options_integration,
    aws_api_gateway_integration.getreviews_options_integration,
    aws_api_gateway_integration.login_options_integration,
    aws_api_gateway_integration.deletereview_options_integration
  ]

  triggers = {
    # This forces a redeployment when any of the integrations change
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_integration.getreviews_integration.id,
      aws_api_gateway_integration.login_integration.id,
      aws_api_gateway_integration.deletereview_integration.id,
      aws_api_gateway_integration.addreview_options_integration.id,
      aws_api_gateway_integration.getreviews_options_integration.id,
      aws_api_gateway_integration.login_options_integration.id,
      aws_api_gateway_integration.deletereview_options_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.backend_api.id
  deployment_id = aws_api_gateway_deployment.backend_deployment.id
}

# Outputs
output "lambda_function_name" {
  value = aws_lambda_function.backend_lambda.function_name
}

output "api_gateway_login_url" {
  value = "https://${aws_api_gateway_rest_api.backend_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod/api/User/Login"
}

output "api_gateway_getreviews_url" {
  value = "https://${aws_api_gateway_rest_api.backend_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod/api/Review/GetReviews"
}

output "api_gateway_addreview_url" {
  value = "https://${aws_api_gateway_rest_api.backend_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod/api/Review/AddReview"
}

output "api_gateway_deletereview_url" {
  value = "https://${aws_api_gateway_rest_api.backend_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod/api/Review/DeleteReview"
}