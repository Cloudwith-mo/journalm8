variable "raw_bucket_name" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "artifacts_bucket_name" {
  type = string
}

variable "tags" {
  type = map(string)
}
