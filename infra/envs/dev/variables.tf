variable "aws_region" {
  description = "AWS region for dev resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile Terraform should use"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "journalm8"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "mko"
}
