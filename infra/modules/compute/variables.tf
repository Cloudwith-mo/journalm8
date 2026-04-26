variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "raw_bucket_name" {
  type = string
}

variable "lambda_source_dir" {
  type = string
}

variable "lambda_zip_path" {
  type = string
}

variable "url_expiration_seconds" {
  type    = number
  default = 900
}

variable "processed_bucket_name" {
  type = string
}

variable "journal_entries_table_name" {
  type = string
}

variable "list_entries_lambda_source_dir" {
  type = string
}

variable "list_entries_lambda_zip_path" {
  type = string
}

variable "get_entry_lambda_source_dir" {
  type = string
}

variable "get_entry_lambda_zip_path" {
  type = string
}

variable "update_transcript_lambda_source_dir" {
  type = string
}

variable "update_transcript_lambda_zip_path" {
  type = string
}

variable "enrich_entry_lambda_source_dir" {
  type = string
}

variable "enrich_entry_lambda_zip_path" {
  type = string
}

variable "get_insight_lambda_source_dir" {
  type = string
}

variable "get_insight_lambda_zip_path" {
  type = string
}

variable "weekly_reflection_lambda_source_dir" {
  type = string
}

variable "weekly_reflection_lambda_zip_path" {
  type = string
}

variable "retry_enrich_lambda_source_dir" {
  type = string
}

variable "retry_enrich_lambda_zip_path" {
  type = string
}

variable "ai_provider" {
  description = "AI provider for enrichment Lambdas. 'bedrock' for production, 'mock' for dev validation."
  type        = string
  default     = "bedrock"

  validation {
    condition     = contains(["bedrock", "mock"], var.ai_provider)
    error_message = "ai_provider must be 'bedrock' or 'mock'."
  }
}

variable "bedrock_model_id" {
  description = "Bedrock model ID used by enrichment and reflection Lambdas."
  type        = string
  default     = "us.anthropic.claude-3-5-haiku-20241022-v1:0"
}

variable "max_input_chars" {
  description = "Max characters of transcript text sent to the model."
  type        = number
  default     = 4000
}

variable "max_output_tokens" {
  description = "Max tokens the model may produce per enrichment call."
  type        = number
  default     = 600
}

variable "tags" {
  type = map(string)
}
