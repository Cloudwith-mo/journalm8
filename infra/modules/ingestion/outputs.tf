output "lambda_function_name" {
  value = aws_lambda_function.start_ingestion.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.start_ingestion.arn
}
