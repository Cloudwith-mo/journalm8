output "lambda_function_name" {
  value = aws_lambda_function.ocr_document.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.ocr_document.arn
}

output "pillow_layer_arn" {
  value = aws_lambda_layer_version.pillow.arn
}
