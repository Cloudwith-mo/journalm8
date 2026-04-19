output "knowledge_base_id" {
  value = aws_bedrock_knowledge_base.journal.id
}

output "knowledge_base_arn" {
  value = aws_bedrock_knowledge_base.journal.arn
}

output "data_source_id" {
  value = aws_bedrock_data_source.journal_processed.id
}
