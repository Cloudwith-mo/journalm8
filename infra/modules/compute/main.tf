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
      ENRICH_ENTRY_FUNCTION_NAME = "${var.project_name}-${var.environment}-enrich-entry"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.update_transcript
  ]

  tags = var.tags
}

# ========== ENRICH_ENTRY Lambda ==========
data "archive_file" "enrich_entry" {
  type        = "zip"
  source_dir  = var.enrich_entry_lambda_source_dir
  output_path = var.enrich_entry_lambda_zip_path
}

resource "aws_iam_role" "enrich_entry" {
  name               = "${var.project_name}-${var.environment}-enrich-entry-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "enrich_entry_inline" {
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
    sid    = "AllowS3ReadTranscript"
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.processed_bucket_name}/*"]
  }

  statement {
    sid    = "AllowDynamoDBReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }

  statement {
    sid    = "AllowBedrockInvoke"
    effect = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "enrich_entry" {
  name   = "${var.project_name}-${var.environment}-enrich-entry-inline"
  role   = aws_iam_role.enrich_entry.id
  policy = data.aws_iam_policy_document.enrich_entry_inline.json
}

resource "aws_cloudwatch_log_group" "enrich_entry" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-enrich-entry"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "enrich_entry" {
  function_name    = "${var.project_name}-${var.environment}-enrich-entry"
  role             = aws_iam_role.enrich_entry.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.enrich_entry.output_path
  source_code_hash = data.archive_file.enrich_entry.output_base64sha256

  timeout     = 120
  memory_size = 512
  publish     = false

  environment {
    variables = {
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
      PROCESSED_BUCKET_NAME      = var.processed_bucket_name
      BEDROCK_MODEL_ID           = var.bedrock_model_id
      AI_PROVIDER                = var.ai_provider
      MAX_INPUT_CHARS            = tostring(var.max_input_chars)
      MAX_OUTPUT_TOKENS          = tostring(var.max_output_tokens)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.enrich_entry
  ]

  tags = var.tags
}

# Allow update_transcript to invoke enrich_entry async
resource "aws_iam_role_policy" "update_transcript_invoke_enrich" {
  name = "${var.project_name}-${var.environment}-update-transcript-invoke-enrich"
  role = aws_iam_role.update_transcript.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowInvokeEnrichEntry"
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.enrich_entry.arn
    }]
  })
}

# ========== GET_INSIGHT Lambda ==========
data "archive_file" "get_insight" {
  type        = "zip"
  source_dir  = var.get_insight_lambda_source_dir
  output_path = var.get_insight_lambda_zip_path
}

resource "aws_iam_role" "get_insight" {
  name               = "${var.project_name}-${var.environment}-get-insight-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "get_insight_inline" {
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
    actions = ["dynamodb:GetItem"]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }
}

resource "aws_iam_role_policy" "get_insight" {
  name   = "${var.project_name}-${var.environment}-get-insight-inline"
  role   = aws_iam_role.get_insight.id
  policy = data.aws_iam_policy_document.get_insight_inline.json
}

resource "aws_cloudwatch_log_group" "get_insight" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-get-insight"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "get_insight" {
  function_name    = "${var.project_name}-${var.environment}-get-insight"
  role             = aws_iam_role.get_insight.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.get_insight.output_path
  source_code_hash = data.archive_file.get_insight.output_base64sha256

  timeout     = 10
  memory_size = 256
  publish     = false

  environment {
    variables = {
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.get_insight
  ]

  tags = var.tags
}

# ========== WEEKLY_REFLECTION Lambda ==========
data "archive_file" "weekly_reflection" {
  type        = "zip"
  source_dir  = var.weekly_reflection_lambda_source_dir
  output_path = var.weekly_reflection_lambda_zip_path
}

resource "aws_iam_role" "weekly_reflection" {
  name               = "${var.project_name}-${var.environment}-weekly-reflection-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "weekly_reflection_inline" {
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
    sid    = "AllowDynamoDBReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:Query",
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }

  statement {
    sid    = "AllowBedrockInvoke"
    effect = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "weekly_reflection" {
  name   = "${var.project_name}-${var.environment}-weekly-reflection-inline"
  role   = aws_iam_role.weekly_reflection.id
  policy = data.aws_iam_policy_document.weekly_reflection_inline.json
}

resource "aws_cloudwatch_log_group" "weekly_reflection" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-weekly-reflection"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "weekly_reflection" {
  function_name    = "${var.project_name}-${var.environment}-weekly-reflection"
  role             = aws_iam_role.weekly_reflection.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.weekly_reflection.output_path
  source_code_hash = data.archive_file.weekly_reflection.output_base64sha256

  timeout     = 120
  memory_size = 512
  publish     = false

  environment {
    variables = {
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
      BEDROCK_MODEL_ID           = var.bedrock_model_id
      AI_PROVIDER                = var.ai_provider
      MAX_INPUT_CHARS            = tostring(var.max_input_chars)
      MAX_OUTPUT_TOKENS          = tostring(var.max_output_tokens)
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.weekly_reflection
  ]

  tags = var.tags
}

# ========== RETRY_ENRICH Lambda ==========
data "archive_file" "retry_enrich" {
  type        = "zip"
  source_dir  = var.retry_enrich_lambda_source_dir
  output_path = var.retry_enrich_lambda_zip_path
}

resource "aws_iam_role" "retry_enrich" {
  name               = "${var.project_name}-${var.environment}-retry-enrich-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "retry_enrich_inline" {
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
    sid    = "AllowDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.journal_entries_table_name}"
    ]
  }

  statement {
    sid    = "AllowInvokeEnrichEntry"
    effect = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:*:*:function:${var.project_name}-${var.environment}-enrich-entry"]
  }
}

resource "aws_iam_role_policy" "retry_enrich" {
  name   = "${var.project_name}-${var.environment}-retry-enrich-inline"
  role   = aws_iam_role.retry_enrich.id
  policy = data.aws_iam_policy_document.retry_enrich_inline.json
}

resource "aws_cloudwatch_log_group" "retry_enrich" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-retry-enrich"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_lambda_function" "retry_enrich" {
  function_name    = "${var.project_name}-${var.environment}-retry-enrich"
  role             = aws_iam_role.retry_enrich.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.13"
  filename         = data.archive_file.retry_enrich.output_path
  source_code_hash = data.archive_file.retry_enrich.output_base64sha256

  timeout     = 10
  memory_size = 256
  publish     = false

  environment {
    variables = {
      JOURNAL_ENTRIES_TABLE_NAME = var.journal_entries_table_name
      ENRICH_ENTRY_FUNCTION_NAME = "${var.project_name}-${var.environment}-enrich-entry"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.retry_enrich
  ]

  tags = var.tags
}
