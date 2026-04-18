output "state_machine_arn" {
  value = aws_sfn_state_machine.journal_ingestion.arn
}

output "state_machine_name" {
  value = aws_sfn_state_machine.journal_ingestion.name
}
