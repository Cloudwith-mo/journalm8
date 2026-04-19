data "archive_file" "ask" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = var.lambda_zip_path
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ask" {
  name               = "${var.project_name}-${var.environment}-ask-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ask_inline" {
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid    = "AllowBedrockRetrieveAndGenerate"
    effect = "Allow"
    actions = [
      "bedrock:RetrieveAndGenerate"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBedrockRetrieve"
    effect = "Allow"
    actions = [
      "bedrock:Retrieve"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ask" {
  name   = "${var.project_name}-${var.environment}-ask-inline"
  role   = aws_iam_role.ask.id
  policy = data.aws_iam_policy_document.ask_inline.json
}

resource "aws_cloudwatch_log_group" "ask" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-ask"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "ask" {
  function_name = "${var.project_name}-${var.environment}-ask"
  role          = aws_iam_role.ask.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  filename      = data.archive_file.ask.output_path

  source_code_hash = data.archive_file.ask.output_base64sha256

  timeout     = 60
  memory_size = 512
  publish     = false

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.ask
  ]

  tags = var.tags
}
