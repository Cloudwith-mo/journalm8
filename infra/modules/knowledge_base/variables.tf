variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "processed_bucket_arn" {
  type = string
}

variable "tags" {
  type = map(string)
}
