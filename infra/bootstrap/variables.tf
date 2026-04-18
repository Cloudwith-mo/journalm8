variable "aws_region" {
  description = "AWS region for bootstrap resources"
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
  default     = "bootstrap"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "mko"
}

variable "terraform_state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state"
  type        = string
}

variable "force_destroy_state_bucket" {
  description = "Allow Terraform to destroy the state bucket even if it contains objects"
  type        = bool
  default     = false
}
