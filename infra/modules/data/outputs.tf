output "journal_entries_table_name" {
  value = aws_dynamodb_table.journal_entries.name
}

output "journal_entries_table_arn" {
  value = aws_dynamodb_table.journal_entries.arn
}

output "ingestion_jobs_table_name" {
  value = aws_dynamodb_table.ingestion_jobs.name
}

output "ingestion_jobs_table_arn" {
  value = aws_dynamodb_table.ingestion_jobs.arn
}
