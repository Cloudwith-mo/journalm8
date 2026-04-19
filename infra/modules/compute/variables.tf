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

variable "tags" {
  type = map(string)
}
