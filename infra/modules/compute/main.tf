data "archive_file" "presign_upload" {
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

resource "aws_iam_role" "presign_upload" {
  name               = "${var.project_name}-${var.environment}-presign-upload-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "presign_upload_inline" {
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
    sid    = "AllowPutObjectToRawBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.raw_bucket_name}/users/*"
    ]
  }
}

resource "aws_iam_role_policy" "presign_upload" {
  name   = "${var.project_name}-${var.environment}-presign-upload-inline"
  role   = aws_iam_role.presign_upload.id
  policy = data.aws_iam_policy_document.presign_upload_inline.json
}

resource "aws_cloudwatch_log_group" "presign_upload" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-presign-upload"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "presign_upload" {
  function_name = "${var.project_name}-${var.environment}-presign-upload"
  role          = aws_iam_role.presign_upload.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  filename      = data.archive_file.presign_upload.output_path

  source_code_hash = data.archive_file.presign_upload.output_base64sha256

  timeout      = 10
  memory_size  = 256
  publish      = false

  environment {
    variables = {
      RAW_BUCKET_NAME         = var.raw_bucket_name
      URL_EXPIRATION_SECONDS  = tostring(var.url_expiration_seconds)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.presign_upload
  ]

  tags = var.tags
}
