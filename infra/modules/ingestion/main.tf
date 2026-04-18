data "archive_file" "start_ingestion" {
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

resource "aws_iam_role" "start_ingestion" {
  name               = "${var.project_name}-${var.environment}-start-ingestion-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "start_ingestion_inline" {
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
    sid    = "AllowDynamoDBPutJob"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]
    resources = [
      var.ingestion_jobs_table_arn
    ]
  }

  statement {
    sid    = "AllowStartExecution"
    effect = "Allow"
    actions = [
      "states:StartExecution"
    ]
    resources = [
      var.state_machine_arn
    ]
  }
}

resource "aws_iam_role_policy" "start_ingestion" {
  name   = "${var.project_name}-${var.environment}-start-ingestion-inline"
  role   = aws_iam_role.start_ingestion.id
  policy = data.aws_iam_policy_document.start_ingestion_inline.json
}

resource "aws_cloudwatch_log_group" "start_ingestion" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-start-ingestion"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "start_ingestion" {
  function_name = "${var.project_name}-${var.environment}-start-ingestion"
  role          = aws_iam_role.start_ingestion.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  filename      = data.archive_file.start_ingestion.output_path

  source_code_hash = data.archive_file.start_ingestion.output_base64sha256

  timeout     = 15
  memory_size = 256
  publish     = false

  environment {
    variables = {
      INGESTION_JOBS_TABLE_NAME = var.ingestion_jobs_table_name
      STATE_MACHINE_ARN         = var.state_machine_arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.start_ingestion
  ]

  tags = var.tags
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3RawBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ingestion.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.raw_bucket_arn
}

resource "aws_s3_bucket_notification" "raw_object_created" {
  bucket = var.raw_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.start_ingestion.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "users/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}
