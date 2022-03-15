terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  force_destroy = true
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name         = "users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"
  attribute {
    name = "email"
    type = "S"
  }
  tags = {
    environment = "dev"
  }
}

resource "aws_cognito_user_pool" "main" {
  name                     = "MyUserPool"
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]
  schema {
    attribute_data_type = "String"
    mutable             = true
    name                = "name"
    required            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }
  schema {
    attribute_data_type = "String"
    mutable             = true
    name                = "email"
    required            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  password_policy {
    minimum_length    = "8"
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  mfa_configuration = "OFF"

  lambda_config {
    post_confirmation = aws_lambda_function.create_order.arn
  }
}


resource "aws_cognito_user_pool_client" "client" {
  name = "cognito-client"

  user_pool_id        = aws_cognito_user_pool.main.id
  generate_secret     = false
  explicit_auth_flows = ["ADMIN_NO_SRP_AUTH"]
}

data "archive_file" "lambda_order" {
  type = "zip"

  source_dir  = "${path.module}/order"
  output_path = "${path.module}/order.zip"
}

resource "aws_s3_object" "lambda_order" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "order.zip"
  source = data.archive_file.lambda_order.output_path

  etag = filemd5(data.archive_file.lambda_order.output_path)
}


resource "aws_lambda_function" "get_order" {
  function_name = "getOrder"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_order.key

  runtime = "nodejs12.x"
  handler = "getOrder.handler"

  source_code_hash = data.archive_file.lambda_order.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "get_orders" {
  function_name = "getOrders"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_order.key

  runtime = "nodejs12.x"
  handler = "getOrders.handler"

  source_code_hash = data.archive_file.lambda_order.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "create_order" {
  function_name = "createOrder"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_order.key

  runtime = "nodejs12.x"
  handler = "createOrder.handler"

  source_code_hash = data.archive_file.lambda_order.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "update_order" {
  function_name = "updateOrder"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_order.key

  runtime = "nodejs12.x"
  handler = "updateOrder.handler"

  source_code_hash = data.archive_file.lambda_order.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "delete_order" {
  function_name = "deleteOrder"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_order.key

  runtime = "nodejs12.x"
  handler = "deleteOrder.handler"

  source_code_hash = data.archive_file.lambda_order.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}


resource "aws_lambda_function" "signup" {
  function_name = "signUp"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_order.key

  runtime = "nodejs12.x"
  handler = "signUp.handler"

  source_code_hash = data.archive_file.lambda_order.output_base64sha256

  role = aws_iam_role.lambda_exec.arn


  environment {
    variables = {
      user_pool_id = aws_cognito_user_pool.main.id
    }
  }
}

resource "aws_cloudwatch_log_group" "get_order" {
  name = "/aws/lambda/${aws_lambda_function.get_order.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "get_orders" {
  name = "/aws/lambda/${aws_lambda_function.get_orders.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "create_order" {
  name = "/aws/lambda/${aws_lambda_function.create_order.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "update_order" {
  name = "/aws/lambda/${aws_lambda_function.update_order.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "delete_order" {
  name = "/aws/lambda/${aws_lambda_function.delete_order.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "signup" {
  name = "/aws/lambda/${aws_lambda_function.signup.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource" : "arn:aws:dynamodb:us-east-1:251702461421:table/users"
      }
    ]
  })
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "get_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_order.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "get_orders" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_orders.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "create_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.create_order.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "update_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.update_order.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "delete_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.delete_order.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "signup" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.signup.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}



resource "aws_apigatewayv2_route" "get_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /get_order"
  target    = "integrations/${aws_apigatewayv2_integration.get_order.id}"
}

resource "aws_apigatewayv2_route" "get_orders" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /get_orders"
  target    = "integrations/${aws_apigatewayv2_integration.get_orders.id}"
}

resource "aws_apigatewayv2_route" "create_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /create_order"
  target    = "integrations/${aws_apigatewayv2_integration.create_order.id}"
}

resource "aws_apigatewayv2_route" "update_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "PUT /update_order"
  target    = "integrations/${aws_apigatewayv2_integration.update_order.id}"
}

resource "aws_apigatewayv2_route" "delete_order" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /delete_order"
  target    = "integrations/${aws_apigatewayv2_integration.delete_order.id}"
}

resource "aws_apigatewayv2_route" "signup" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /signup"
  target    = "integrations/${aws_apigatewayv2_integration.signup.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_get_order" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_order.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_get_orders" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_orders.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_create_order" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_order.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_update_order" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_order.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_delete_order" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_order.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_signup" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signup.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
