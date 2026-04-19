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

# ========== LIST_ENTRIES Lambda ==========
data "archive_file" "list_entries" {
  type        = "zip"
  source_dir  = var.list_entries_lambda_source_dir
  output_path = var.list_entries_lambda_zip_path
}

resource "aws_iam_role" "list_entries" {
  name               = "${var.project_name}-${var.environment}-list-entries-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "list_entries_inline" {
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
    sid    = "AllowDynamoDBQuery"
    effect = "Allow"
    actions = [
      "dynamodb:Query"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }
}

resource "aws_iam_role_policy" "list_entries" {
  name   = "${var.project_name}-${var.environment}-list-entries-inline"
  role   = aws_iam_role.list_entries.id
  policy = data.aws_iam_policy_document.list_entries_inline.json
}

resource "aws_cloudwatch_log_group" "list_entries" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-list-entries"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "list_entries" {
  function_name    = "${var.project_name}-${var.environment}-list-entries"
  role             = aws_iam_role.list_entries.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.list_entries.output_path
  source_code_hash = data.archive_file.list_entries.output_base64sha256

  timeout     = 10
  memory_size = 256
  publish     = false

  environment {
    variables = {
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.list_entries
  ]

  tags = var.tags
}

# ========== GET_ENTRY Lambda ==========
data "archive_file" "get_entry" {
  type        = "zip"
  source_dir  = var.get_entry_lambda_source_dir
  output_path = var.get_entry_lambda_zip_path
}

resource "aws_iam_role" "get_entry" {
  name               = "${var.project_name}-${var.environment}-get-entry-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "get_entry_inline" {
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
    sid    = "AllowDynamoDBGetItem"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }

  statement {
    sid    = "AllowS3ReadText"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.processed_bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "get_entry" {
  name   = "${var.project_name}-${var.environment}-get-entry-inline"
  role   = aws_iam_role.get_entry.id
  policy = data.aws_iam_policy_document.get_entry_inline.json
}

resource "aws_cloudwatch_log_group" "get_entry" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-get-entry"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "get_entry" {
  function_name    = "${var.project_name}-${var.environment}-get-entry"
  role             = aws_iam_role.get_entry.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.get_entry.output_path
  source_code_hash = data.archive_file.get_entry.output_base64sha256

  timeout     = 10
  memory_size = 256
  publish     = false

  environment {
    variables = {
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
      PROCESSED_BUCKET_NAME      = var.processed_bucket_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.get_entry
  ]

  tags = var.tags
}

# ========== UPDATE_TRANSCRIPT Lambda ==========
data "archive_file" "update_transcript" {
  type        = "zip"
  source_dir  = var.update_transcript_lambda_source_dir
  output_path = var.update_transcript_lambda_zip_path
}

resource "aws_iam_role" "update_transcript" {
  name               = "${var.project_name}-${var.environment}-update-transcript-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "update_transcript_inline" {
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
    sid    = "AllowS3Write"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.processed_bucket_name}/*"
    ]
  }

  statement {
    sid    = "AllowDynamoDBUpdate"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }
}

resource "aws_iam_role_policy" "update_transcript" {
  name   = "${var.project_name}-${var.environment}-update-transcript-inline"
  role   = aws_iam_role.update_transcript.id
  policy = data.aws_iam_policy_document.update_transcript_inline.json
}

resource "aws_cloudwatch_log_group" "update_transcript" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-update-transcript"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "update_transcript" {
  function_name    = "${var.project_name}-${var.environment}-update-transcript"
  role             = aws_iam_role.update_transcript.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.update_transcript.output_path
  source_code_hash = data.archive_file.update_transcript.output_base64sha256

  timeout     = 10
  memory_size = 256
  publish     = false

  environment {
    variables = {
      PROCESSED_BUCKET_NAME      = var.processed_bucket_name
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.update_transcript
  ]

  tags = var.tags
}
