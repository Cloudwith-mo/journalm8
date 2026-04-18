variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "raw_bucket_name" {
  type = string
}

variable "raw_bucket_arn" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "processed_bucket_arn" {
  type = string
}

variable "ingestion_jobs_table_name" {
  type = string
}

variable "ingestion_jobs_table_arn" {
  type = string
}

variable "journal_entries_table_name" {
  type = string
}

variable "journal_entries_table_arn" {
  type = string
}

variable "lambda_source_dir" {
  type = string
}

variable "lambda_zip_path" {
  type = string
}

variable "tags" {
  type = map(string)
}
