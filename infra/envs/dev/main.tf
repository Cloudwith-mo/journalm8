data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }

  name_prefix = "${var.project_name}-${var.environment}"

  raw_bucket_name       = "${local.name_prefix}-raw-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  processed_bucket_name = "${local.name_prefix}-processed-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  artifacts_bucket_name = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

module "auth" {
  source = "../../modules/auth"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  raw_bucket_name       = local.raw_bucket_name
  processed_bucket_name = local.processed_bucket_name
  artifacts_bucket_name = local.artifacts_bucket_name
  tags                  = local.common_tags
}

module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}
