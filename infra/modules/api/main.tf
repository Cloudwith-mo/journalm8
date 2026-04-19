resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-${var.environment}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["authorization", "content-type"]
    expose_headers = ["content-type"]
    max_age        = 300
  }

  tags = var.tags
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.this.id
  name             = "${var.project_name}-${var.environment}-jwt-authorizer"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.cognito_user_pool_client_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

resource "aws_apigatewayv2_integration" "presign_upload" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "presign_upload" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /uploads/presign"
  target             = "integrations/${aws_apigatewayv2_integration.presign_upload.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_integration" "ask" {
  count = var.ask_lambda_invoke_arn != "" ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.ask_lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 60000
}

resource "aws_apigatewayv2_route" "ask" {
  count = var.ask_lambda_invoke_arn != "" ? 1 : 0

  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "POST /ask"
  target             = "integrations/${aws_apigatewayv2_integration.ask[0].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# ========== LIST_ENTRIES Route ==========
resource "aws_apigatewayv2_integration" "list_entries" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.list_entries_lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "list_entries" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /entries"
  target             = "integrations/${aws_apigatewayv2_integration.list_entries.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# ========== GET_ENTRY Route ==========
resource "aws_apigatewayv2_integration" "get_entry" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.get_entry_lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "get_entry" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /entries/{entryId}"
  target             = "integrations/${aws_apigatewayv2_integration.get_entry.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# ========== UPDATE_TRANSCRIPT Route ==========
resource "aws_apigatewayv2_integration" "update_transcript" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.update_transcript_lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "update_transcript" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "PUT /entries/{entryId}"
  target             = "integrations/${aws_apigatewayv2_integration.update_transcript.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromApiGatewayPresignUpload"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_ask" {
  count = var.ask_lambda_function_name != "" ? 1 : 0

  statement_id  = "AllowExecutionFromApiGatewayAsk"
  action        = "lambda:InvokeFunction"
  function_name = var.ask_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_list_entries" {
  statement_id  = "AllowExecutionFromApiGatewayListEntries"
  action        = "lambda:InvokeFunction"
  function_name = var.list_entries_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_get_entry" {
  statement_id  = "AllowExecutionFromApiGatewayGetEntry"
  action        = "lambda:InvokeFunction"
  function_name = var.get_entry_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_update_transcript" {
  statement_id  = "AllowExecutionFromApiGatewayUpdateTranscript"
  action        = "lambda:InvokeFunction"
  function_name = var.update_transcript_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
