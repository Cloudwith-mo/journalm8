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
  list_entries_lambda_source_dir    = "${abspath(path.root)}/../../../services/api/list_entries"
  list_entries_lambda_zip_path      = "${abspath(path.root)}/list_entries.zip"
  get_entry_lambda_source_dir       = "${abspath(path.root)}/../../../services/api/get_entry"
  get_entry_lambda_zip_path         = "${abspath(path.root)}/get_entry.zip"
  update_transcript_lambda_source_dir = "${abspath(path.root)}/../../../services/api/update_transcript"
  update_transcript_lambda_zip_path = "${abspath(path.root)}/update_transcript.zip"
  enrich_entry_lambda_source_dir    = "${abspath(path.root)}/../../../services/ai/enrich_entry"
  enrich_entry_lambda_zip_path      = "${abspath(path.root)}/enrich_entry.zip"
  get_insight_lambda_source_dir     = "${abspath(path.root)}/../../../services/api/get_insight"
  get_insight_lambda_zip_path       = "${abspath(path.root)}/get_insight.zip"
  weekly_reflection_lambda_source_dir = "${abspath(path.root)}/../../../services/agents/weekly_reflection"
  weekly_reflection_lambda_zip_path = "${abspath(path.root)}/weekly_reflection.zip"
  retry_enrich_lambda_source_dir    = "${abspath(path.root)}/../../../services/api/retry_enrich"
  retry_enrich_lambda_zip_path      = "${abspath(path.root)}/retry_enrich.zip"
  start_ingestion_lambda_source_dir = "${abspath(path.root)}/../../../services/ingestion/start_ingestion"
  start_ingestion_lambda_zip_path   = "${abspath(path.root)}/start_ingestion.zip"
  ocr_lambda_source_dir             = "${abspath(path.root)}/../../../services/ingestion/ocr_document"
  ocr_lambda_zip_path               = "${abspath(path.root)}/ocr_document.zip"
  ask_lambda_source_dir             = "${abspath(path.root)}/../../../services/api/ask"
  ask_lambda_zip_path               = "${abspath(path.root)}/ask.zip"
  sync_kb_lambda_source_dir         = "${abspath(path.root)}/../../../services/sync_kb"
  sync_kb_lambda_zip_path           = "${abspath(path.root)}/sync_kb.zip"
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

module "ocr" {
  source = "../../modules/ocr"

  project_name               = var.project_name
  environment                = var.environment
  raw_bucket_name            = module.storage.raw_bucket_name
  raw_bucket_arn             = module.storage.raw_bucket_arn
  processed_bucket_name      = module.storage.processed_bucket_name
  processed_bucket_arn       = module.storage.processed_bucket_arn
  ingestion_jobs_table_name  = module.data.ingestion_jobs_table_name
  ingestion_jobs_table_arn   = module.data.ingestion_jobs_table_arn
  journal_entries_table_name = module.data.journal_entries_table_name
  journal_entries_table_arn  = module.data.journal_entries_table_arn
  lambda_source_dir          = local.ocr_lambda_source_dir
  lambda_zip_path            = local.ocr_lambda_zip_path
  tags                       = local.common_tags
}

module "workflows" {
  source = "../../modules/workflows"

  project_name   = var.project_name
  environment    = var.environment
  ocr_lambda_arn = module.ocr.lambda_function_arn
  tags           = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  project_name      = var.project_name
  environment       = var.environment
  raw_bucket_name   = module.storage.raw_bucket_name
  processed_bucket_name = module.storage.processed_bucket_name
  journal_entries_table_name = module.data.journal_entries_table_name
  lambda_source_dir = local.presign_lambda_source_dir
  lambda_zip_path   = local.presign_lambda_zip_path
  list_entries_lambda_source_dir = local.list_entries_lambda_source_dir
  list_entries_lambda_zip_path = local.list_entries_lambda_zip_path
  get_entry_lambda_source_dir = local.get_entry_lambda_source_dir
  get_entry_lambda_zip_path = local.get_entry_lambda_zip_path
  update_transcript_lambda_source_dir = local.update_transcript_lambda_source_dir
  update_transcript_lambda_zip_path = local.update_transcript_lambda_zip_path
  enrich_entry_lambda_source_dir    = local.enrich_entry_lambda_source_dir
  enrich_entry_lambda_zip_path      = local.enrich_entry_lambda_zip_path
  get_insight_lambda_source_dir     = local.get_insight_lambda_source_dir
  get_insight_lambda_zip_path       = local.get_insight_lambda_zip_path
  weekly_reflection_lambda_source_dir = local.weekly_reflection_lambda_source_dir
  weekly_reflection_lambda_zip_path = local.weekly_reflection_lambda_zip_path
  retry_enrich_lambda_source_dir    = local.retry_enrich_lambda_source_dir
  retry_enrich_lambda_zip_path      = local.retry_enrich_lambda_zip_path

  # AI provider config — change ai_provider to "mock" for dev validation; default is "bedrock"
  ai_provider       = "bedrock"
  bedrock_model_id  = "us.anthropic.claude-3-5-haiku-20241022-v1:0"
  max_input_chars   = 4000
  max_output_tokens = 600

  tags              = local.common_tags
}

# Phase B: Knowledge Base modules (temporarily disabled for Phase A cleanup)
# module "knowledge_base" {
#   source = "../../modules/knowledge_base"
#
#   project_name           = var.project_name
#   environment            = var.environment
#   aws_region             = var.aws_region
#   processed_bucket_name  = module.storage.processed_bucket_name
#   processed_bucket_arn   = module.storage.processed_bucket_arn
#   tags                   = local.common_tags
#
#   depends_on = [module.storage]
# }
#
# module "ask" {
#   source = "../../modules/ask"
#
#   project_name        = var.project_name
#   environment         = var.environment
#   knowledge_base_id   = module.knowledge_base.knowledge_base_id
#   lambda_source_dir   = local.ask_lambda_source_dir
#   lambda_zip_path     = local.ask_lambda_zip_path
#   tags                = local.common_tags
#
#   depends_on = [module.knowledge_base]
# }
#
# module "sync_kb" {
#   source = "../../modules/sync_kb"
#
#   project_name           = var.project_name
#   environment            = var.environment
#   knowledge_base_id      = module.knowledge_base.knowledge_base_id
#   data_source_id         = module.knowledge_base.data_source_id
#   ocr_complete_queue_arn = module.ocr.ocr_complete_queue_arn
#   lambda_source_dir      = local.sync_kb_lambda_source_dir
#   lambda_zip_path        = local.sync_kb_lambda_zip_path
#   tags                   = local.common_tags
#
#   depends_on = [module.knowledge_base, module.ocr]
# }

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
  list_entries_lambda_function_name = module.compute.list_entries_lambda_function_name
  list_entries_lambda_invoke_arn = module.compute.list_entries_lambda_invoke_arn
  get_entry_lambda_function_name = module.compute.get_entry_lambda_function_name
  get_entry_lambda_invoke_arn = module.compute.get_entry_lambda_invoke_arn
  update_transcript_lambda_function_name = module.compute.update_transcript_lambda_function_name
  update_transcript_lambda_invoke_arn = module.compute.update_transcript_lambda_invoke_arn
  get_insight_lambda_function_name    = module.compute.get_insight_lambda_function_name
  get_insight_lambda_invoke_arn       = module.compute.get_insight_lambda_invoke_arn
  weekly_reflection_lambda_function_name = module.compute.weekly_reflection_lambda_function_name
  weekly_reflection_lambda_invoke_arn = module.compute.weekly_reflection_lambda_invoke_arn
  retry_enrich_lambda_function_name   = module.compute.retry_enrich_lambda_function_name
  retry_enrich_lambda_invoke_arn      = module.compute.retry_enrich_lambda_invoke_arn
  # Phase B: Ask endpoint (temporarily disabled)
  # ask_lambda_function_name    = module.ask.lambda_function_name
  # ask_lambda_invoke_arn       = module.ask.lambda_invoke_arn
  tags                        = local.common_tags
}
