variable "raw_bucket_name" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "artifacts_bucket_name" {
  type = string
}

variable "raw_bucket_allowed_origins" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}
