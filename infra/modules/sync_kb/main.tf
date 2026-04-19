data "archive_file" "sync_kb_lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = var.lambda_zip_path
}

resource "aws_lambda_function" "sync_kb" {
  function_name = "${var.project_name}-sync-kb-${var.environment}"
  runtime       = "python3.13"
  handler       = "app.lambda_handler"
  role          = aws_iam_role.sync_kb_lambda_role.arn
  filename      = data.archive_file.sync_kb_lambda_zip.output_path

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
      DATA_SOURCE_ID    = var.data_source_id
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "sync_kb_lambda_role" {
  name = "${var.project_name}-sync-kb-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "sync_kb_lambda_policy" {
  name = "${var.project_name}-sync-kb-lambda-policy-${var.environment}"
  role = aws_iam_role.sync_kb_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:StartIngestionJob"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_event_source_mapping" "sync_kb_sqs" {
  event_source_arn = var.ocr_complete_queue_arn
  function_name    = aws_lambda_function.sync_kb.arn
  batch_size       = 1
}

resource "aws_lambda_permission" "sync_kb_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync_kb.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = var.ocr_complete_queue_arn
}
