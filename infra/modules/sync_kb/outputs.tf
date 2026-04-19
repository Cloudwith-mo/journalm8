output "sync_kb_lambda_arn" {
  value = aws_lambda_function.sync_kb.arn
}

output "sync_kb_lambda_name" {
  value = aws_lambda_function.sync_kb.function_name
}