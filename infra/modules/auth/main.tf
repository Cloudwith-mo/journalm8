resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-${var.environment}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  mfa_configuration = "OFF"

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project_name}-${var.environment}-web-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"  # For testing with AdminInitiateAuth
  ]

  prevent_user_existence_errors = "ENABLED"

  supported_identity_providers = ["COGNITO"]
}
