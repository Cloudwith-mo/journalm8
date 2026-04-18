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

  presign_lambda_source_dir         = "${abspath(path.root)}/../../../services/api/presign_upload"
  presign_lambda_zip_path           = "${abspath(path.root)}/presign_upload.zip"
  start_ingestion_lambda_source_dir = "${abspath(path.root)}/../../../services/ingestion/start_ingestion"
  start_ingestion_lambda_zip_path   = "${abspath(path.root)}/start_ingestion.zip"
}

module "auth" {
  source = "../../modules/auth"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "storage" {
  source = "../../modules/storage"

  raw_bucket_name            = local.raw_bucket_name
  processed_bucket_name      = local.processed_bucket_name
  artifacts_bucket_name      = local.artifacts_bucket_name
  raw_bucket_allowed_origins = var.web_origins
  tags                       = local.common_tags
}

module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "workflows" {
  source = "../../modules/workflows"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project_name      = var.project_name
  environment       = var.environment
  raw_bucket_name   = module.storage.raw_bucket_name
  lambda_source_dir = local.presign_lambda_source_dir
  lambda_zip_path   = local.presign_lambda_zip_path
  tags              = local.common_tags
}

module "ingestion" {
  source = "../../modules/ingestion"

  project_name              = var.project_name
  environment               = var.environment
  raw_bucket_id             = module.storage.raw_bucket_id
  raw_bucket_name           = module.storage.raw_bucket_name
  raw_bucket_arn            = module.storage.raw_bucket_arn
  ingestion_jobs_table_name = module.data.ingestion_jobs_table_name
  ingestion_jobs_table_arn  = module.data.ingestion_jobs_table_arn
  state_machine_arn         = module.workflows.state_machine_arn
  lambda_source_dir         = local.start_ingestion_lambda_source_dir
  lambda_zip_path           = local.start_ingestion_lambda_zip_path
  tags                      = local.common_tags
}

module "api" {
  source = "../../modules/api"

  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  cors_allow_origins          = var.web_origins
  cognito_user_pool_id        = module.auth.user_pool_id
  cognito_user_pool_client_id = module.auth.user_pool_client_id
  lambda_function_name        = module.compute.presign_lambda_function_name
  lambda_invoke_arn           = module.compute.presign_lambda_invoke_arn
  tags                        = local.common_tags
}
