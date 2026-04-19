variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "knowledge_base_id" {
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
