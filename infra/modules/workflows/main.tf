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

resource "aws_sfn_state_machine" "journal_ingestion" {
  name     = "${var.project_name}-${var.environment}-journal-ingestion"
  role_arn = aws_iam_role.state_machine.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "JournalM8 ingestion workflow skeleton"
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
              { Variable = "$.key", IsPresent = true }
            ]
            Next = "OCRPending"
          }
        ]
        Default = "InvalidInput"
      }

      OCRPending = {
        Type = "Pass"
        Result = {
          stage   = "OCR_PENDING"
          message = "Textract step will be added in the next phase"
        }
        ResultPath = "$.ocr"
        Next       = "CleanupPending"
      }

      CleanupPending = {
        Type = "Pass"
        Result = {
          stage   = "CLEANUP_PENDING"
          message = "Cleanup and normalization step will be added later"
        }
        ResultPath = "$.cleanup"
        Next       = "IndexPending"
      }

      IndexPending = {
        Type = "Pass"
        Result = {
          stage   = "INDEX_PENDING"
          message = "Knowledge base sync step will be added later"
        }
        ResultPath = "$.index"
        Next       = "Succeeded"
      }

      InvalidInput = {
        Type  = "Fail"
        Error = "InvalidInput"
        Cause = "Missing one or more required fields"
      }

      Succeeded = {
        Type = "Succeed"
      }
    }
  })

  tags = var.tags
}
