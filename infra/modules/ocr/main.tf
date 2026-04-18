data "archive_file" "ocr_document" {
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

resource "aws_iam_role" "ocr_document" {
  name               = "${var.project_name}-${var.environment}-ocr-document-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "ocr_document_inline" {
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
    sid    = "AllowTextractDetectDocumentText"
    effect = "Allow"
    actions = [
      "textract:DetectDocumentText"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowReadRawBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${var.raw_bucket_arn}/users/*"
    ]
  }

  statement {
    sid    = "AllowWriteProcessedBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${var.processed_bucket_arn}/users/*"
    ]
  }

  statement {
    sid    = "AllowUpdateIngestionJobs"
    effect = "Allow"
    actions = [
      "dynamodb:UpdateItem"
    ]
    resources = [
      var.ingestion_jobs_table_arn
    ]
  }

  statement {
    sid    = "AllowPutJournalEntries"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]
    resources = [
      var.journal_entries_table_arn
    ]
  }
}

resource "aws_iam_role_policy" "ocr_document" {
  name   = "${var.project_name}-${var.environment}-ocr-document-inline"
  role   = aws_iam_role.ocr_document.id
  policy = data.aws_iam_policy_document.ocr_document_inline.json
}

resource "aws_cloudwatch_log_group" "ocr_document" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-ocr-document"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "ocr_document" {
  function_name = "${var.project_name}-${var.environment}-ocr-document"
  role          = aws_iam_role.ocr_document.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  filename      = data.archive_file.ocr_document.output_path

  source_code_hash = data.archive_file.ocr_document.output_base64sha256

  timeout     = 60
  memory_size = 512
  publish     = false

  environment {
    variables = {
      PROCESSED_BUCKET_NAME      = var.processed_bucket_name
      INGESTION_JOBS_TABLE_NAME  = var.ingestion_jobs_table_name
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.ocr_document
  ]

  tags = var.tags
}
