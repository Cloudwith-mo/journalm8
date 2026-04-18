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

variable "tags" {
  type = map(string)
}
