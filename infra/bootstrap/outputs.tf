output "terraform_state_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "next_step_backend_block" {
  description = "Copy this into infra/envs/dev/backend.tf after bootstrap completes"
  value       = <<EOT
terraform {
  backend "s3" {
    bucket       = "${aws_s3_bucket.terraform_state.bucket}"
    key          = "envs/dev/terraform.tfstate"
    region       = "${var.aws_region}"
    profile      = "${var.aws_profile}"
    use_lockfile = true
  }
}
EOT
}
