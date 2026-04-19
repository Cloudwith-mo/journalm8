output "presign_lambda_function_name" {
  value = aws_lambda_function.presign_upload.function_name
}

output "presign_lambda_function_arn" {
  value = aws_lambda_function.presign_upload.arn
}

output "presign_lambda_invoke_arn" {
  value = aws_lambda_function.presign_upload.invoke_arn
}

output "list_entries_lambda_function_name" {
  value = aws_lambda_function.list_entries.function_name
}

output "list_entries_lambda_invoke_arn" {
  value = aws_lambda_function.list_entries.invoke_arn
}

output "get_entry_lambda_function_name" {
  value = aws_lambda_function.get_entry.function_name
}

output "get_entry_lambda_invoke_arn" {
  value = aws_lambda_function.get_entry.invoke_arn
}

output "update_transcript_lambda_function_name" {
  value = aws_lambda_function.update_transcript.function_name
}

output "update_transcript_lambda_invoke_arn" {
  value = aws_lambda_function.update_transcript.invoke_arn
}
