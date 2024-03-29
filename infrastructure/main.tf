data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  environment = "Sandbox"
  team_name = "Sion"
  service_name = "Blue"
}

locals {
  default_tags = {
    Environment = local.environment
    Team = local.team_name
    Service = local.service_name
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "my_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "sqs:*",
            "dynamodb:*"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = {
    Team = "dojo"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir = "../lambda/src"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_function_name"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.test"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"
}

resource "aws_sqs_queue" "terraform_queue_dojo" {
  name                      = "terraform-dojo-queue"
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.terraform_queue_deadletter.arn
    maxReceiveCount     = 4
  })


  tags = {
    Team = "dojo"
  }
}

resource "aws_sqs_queue" "terraform_queue_deadletter" {
  name = "terraform-dojo-deadletter-queue"
}

### DYNAMODB TABLE ###

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = "Terraform-dojo"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "UserId"
  range_key      = "GameTitle"

  attribute {
    name = "UserId"
    type = "S"
  }

  attribute {
    name = "GameTitle"
    type = "S"
  }

  tags = {
    Team       = "Dojo"
  }
}

resource "aws_api_gateway_rest_api" "terraform_api_gateway" {
  name = "terraform_api_gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "terraform_api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.terraform_api_gateway.id

  lifecycle {
    create_before_destroy = true
  }
#  depends_on = [aws_api_gateway_rest_api.terraform_api_gateway]
}

resource "aws_api_gateway_stage" "terraform_api_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.terraform_api_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.terraform_api_gateway.id
  stage_name    = "dev"
#  depends_on = [aws_api_gateway_rest_api.terraform_api_gateway]
}

resource "aws_api_gateway_resource" "terraform_api_resource_message" {
  rest_api_id = aws_api_gateway_rest_api.terraform_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.terraform_api_gateway.root_resource_id
  path_part   = "message"
}

resource "aws_api_gateway_method" "terraform_api_gateway_method_post" {
  rest_api_id   = aws_api_gateway_rest_api.terraform_api_gateway.id
  resource_id   = aws_api_gateway_resource.terraform_api_resource_message.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id          = aws_api_gateway_rest_api.terraform_api_gateway.id
  resource_id          = aws_api_gateway_resource.terraform_api_resource_message.id
  http_method          = aws_api_gateway_method.terraform_api_gateway_method_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.test_lambda.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.aws_region}:900852371335:${aws_api_gateway_rest_api.terraform_api_gateway.id}/*/${aws_api_gateway_method.terraform_api_gateway_method_post.http_method}${aws_api_gateway_resource.terraform_api_resource_message.path}"
}