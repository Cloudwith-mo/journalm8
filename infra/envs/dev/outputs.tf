output "cognito_user_pool_id" {
  value       = module.auth.user_pool_id
  description = "Cognito User Pool ID"
}

output "cognito_user_pool_client_id" {
  value       = module.auth.user_pool_client_id
  description = "Cognito App Client ID"
}

output "raw_bucket_name" {
  value       = module.storage.raw_bucket_name
  description = "Raw uploads bucket"
}

output "processed_bucket_name" {
  value       = module.storage.processed_bucket_name
  description = "Processed documents bucket"
}

output "artifacts_bucket_name" {
  value       = module.storage.artifacts_bucket_name
  description = "Artifacts bucket"
}

output "journal_entries_table_name" {
  value       = module.data.journal_entries_table_name
  description = "Journal entries DynamoDB table"
}

output "ingestion_jobs_table_name" {
  value       = module.data.ingestion_jobs_table_name
  description = "Ingestion jobs DynamoDB table"
}

output "presign_lambda_function_name" {
  value       = module.compute.presign_lambda_function_name
  description = "Presign upload Lambda function name"
}

output "start_ingestion_lambda_function_name" {
  value       = module.ingestion.lambda_function_name
  description = "S3 starter Lambda function name"
}

output "ocr_lambda_function_name" {
  value       = module.ocr.lambda_function_name
  description = "OCR Lambda function name"
}

output "state_machine_arn" {
  value       = module.workflows.state_machine_arn
  description = "Step Functions state machine ARN"
}

output "http_api_endpoint" {
  value       = module.api.api_endpoint
  description = "HTTP API base endpoint"
}
