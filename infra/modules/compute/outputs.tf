output "presign_lambda_function_name" {
  value = aws_lambda_function.presign_upload.function_name
}

output "presign_lambda_function_arn" {
  value = aws_lambda_function.presign_upload.arn
}

output "presign_lambda_invoke_arn" {
  value = aws_lambda_function.presign_upload.invoke_arn
}
