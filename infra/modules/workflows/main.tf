data "aws_iam_policy_document" "step_functions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "state_machine" {
  name               = "${var.project_name}-${var.environment}-journal-ingestion-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.step_functions_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "state_machine_inline" {
  statement {
    sid    = "AllowInvokeOcrLambda"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      var.ocr_lambda_arn
    ]
  }
}

resource "aws_iam_role_policy" "state_machine" {
  name   = "${var.project_name}-${var.environment}-journal-ingestion-sfn-inline"
  role   = aws_iam_role.state_machine.id
  policy = data.aws_iam_policy_document.state_machine_inline.json
}

resource "aws_sfn_state_machine" "journal_ingestion" {
  name     = "${var.project_name}-${var.environment}-journal-ingestion"
  role_arn = aws_iam_role.state_machine.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "JournalM8 ingestion workflow with OCR"
    StartAt = "ValidateInput"
    States = {
      ValidateInput = {
        Type = "Choice"
        Choices = [
          {
            And = [
              { Variable = "$.jobId", IsPresent = true },
              { Variable = "$.userId", IsPresent = true },
              { Variable = "$.entryId", IsPresent = true },
              { Variable = "$.bucket", IsPresent = true },
              { Variable = "$.key", IsPresent = true },
              { Variable = "$.filename", IsPresent = true }
            ]
            Next = "OCRDocument"
          }
        ]
        Default = "InvalidInput"
      }

      OCRDocument = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.ocr_lambda_arn
          Payload = {
            "jobId.$"    = "$.jobId"
            "userId.$"   = "$.userId"
            "entryId.$"  = "$.entryId"
            "bucket.$"   = "$.bucket"
            "key.$"      = "$.key"
            "filename.$" = "$.filename"
          }
        }
        OutputPath = "$.Payload"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "States.TaskFailed"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "Failed"
          }
        ]
        Next = "Succeeded"
      }

      InvalidInput = {
        Type  = "Fail"
        Error = "InvalidInput"
        Cause = "Missing one or more required fields"
      }

      Failed = {
        Type  = "Fail"
        Error = "OCRFailed"
        Cause = "OCR step failed"
      }

      Succeeded = {
        Type = "Succeed"
      }
    }
  })

  tags = var.tags
}
