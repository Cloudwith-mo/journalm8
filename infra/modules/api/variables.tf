variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cors_allow_origins" {
  type = list(string)
}

variable "cognito_user_pool_id" {
  type = string
}

variable "cognito_user_pool_client_id" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "ask_lambda_function_name" {
  type    = string
  default = ""  # Optional for Phase A
}

variable "ask_lambda_invoke_arn" {
  type    = string
  default = ""  # Optional for Phase A
}

variable "list_entries_lambda_function_name" {
  type = string
}

variable "list_entries_lambda_invoke_arn" {
  type = string
}

variable "get_entry_lambda_function_name" {
  type = string
}

variable "get_entry_lambda_invoke_arn" {
  type = string
}

variable "update_transcript_lambda_function_name" {
  type = string
}

variable "update_transcript_lambda_invoke_arn" {
  type = string
}

variable "get_insight_lambda_function_name" {
  type = string
}

variable "get_insight_lambda_invoke_arn" {
  type = string
}

variable "weekly_reflection_lambda_function_name" {
  type = string
}

variable "weekly_reflection_lambda_invoke_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}
