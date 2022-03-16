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
    post_confirmation = aws_lambda_function.post_confirmation.arn
  }
}


resource "aws_cognito_user_pool_client" "client" {
  name = "cognito-client"

  user_pool_id        = aws_cognito_user_pool.main.id
  generate_secret     = false
  explicit_auth_flows = ["ADMIN_NO_SRP_AUTH"]
}

data "archive_file" "lambda_user" {
  type = "zip"

  source_dir  = "${path.module}/user"
  output_path = "${path.module}/user.zip"
}

resource "aws_s3_object" "lambda_user" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "user.zip"
  source = data.archive_file.lambda_user.output_path

  etag = filemd5(data.archive_file.lambda_user.output_path)
}


resource "aws_lambda_function" "get_user" {
  function_name = "getUser"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "getUser.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "get_users" {
  function_name = "getUsers"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "getUsers.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = "postConfirmation"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "postConfirmation.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "update_user" {
  function_name = "updateUser"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "updateUser.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function" "delete_user" {
  function_name = "deleteUser"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "deleteUser.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}


resource "aws_lambda_function" "signup" {
  function_name = "signUp"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "signUp.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn


  environment {
    variables = {
      user_pool_id = aws_cognito_user_pool.main.id
      client_id    = aws_cognito_user_pool_client.client.id
    }
  }
}

resource "aws_lambda_function" "signin" {
  function_name = "signIn"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_user.key

  runtime = "nodejs12.x"
  handler = "signIn.handler"

  source_code_hash = data.archive_file.lambda_user.output_base64sha256

  role = aws_iam_role.lambda_exec.arn


  environment {
    variables = {
      user_pool_id = aws_cognito_user_pool.main.id
      client_id    = aws_cognito_user_pool_client.client.id
    }
  }
}

resource "aws_cloudwatch_log_group" "get_user" {
  name = "/aws/lambda/${aws_lambda_function.get_user.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "get_users" {
  name = "/aws/lambda/${aws_lambda_function.get_users.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "post_confirmation" {
  name = "/aws/lambda/${aws_lambda_function.post_confirmation.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "update_user" {
  name = "/aws/lambda/${aws_lambda_function.update_user.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "delete_user" {
  name = "/aws/lambda/${aws_lambda_function.delete_user.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "signup" {
  name = "/aws/lambda/${aws_lambda_function.signup.function_name}"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "signin" {
  name = "/aws/lambda/${aws_lambda_function.signin.function_name}"

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
      "Resource" : "${aws_dynamodb_table.dynamodb_table.arn}"
      }
    ]
  })
}


resource "aws_iam_role_policy" "cognito_policy" {
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "cognito-idp:AdminInitiateAuth",
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminSetUserPassword"
      ],
      "Resource" : "${aws_cognito_user_pool.main.arn}"
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

resource "aws_apigatewayv2_integration" "get_user" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_user.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "get_users" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.get_users.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "update_user" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.update_user.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "delete_user" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.delete_user.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "signup" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.signup.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "signin" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.signin.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_user" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /get_user"
  target    = "integrations/${aws_apigatewayv2_integration.get_user.id}"
}

resource "aws_apigatewayv2_route" "get_users" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /get_users"
  target    = "integrations/${aws_apigatewayv2_integration.get_users.id}"
}

resource "aws_apigatewayv2_route" "update_user" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "PUT /update_user"
  target    = "integrations/${aws_apigatewayv2_integration.update_user.id}"
}

resource "aws_apigatewayv2_route" "delete_user" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "DELETE /delete_user"
  target    = "integrations/${aws_apigatewayv2_integration.delete_user.id}"
}

resource "aws_apigatewayv2_route" "signup" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /signup"
  target    = "integrations/${aws_apigatewayv2_integration.signup.id}"
}

resource "aws_apigatewayv2_route" "signin" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /signin"
  target    = "integrations/${aws_apigatewayv2_integration.signin.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_get_user" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_get_users" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_users.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_update_user" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_user.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_delete_user" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_user.function_name
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

resource "aws_lambda_permission" "api_gw_signin" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signin.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}


resource "aws_lambda_permission" "post_confirmation" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
  depends_on    = [aws_lambda_function.post_confirmation]
}
