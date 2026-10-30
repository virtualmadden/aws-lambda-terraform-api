# An HTTP API (API Gateway v2) that sends every request to the function, which routes in
# code. The default execute-api URL is off, so the custom domain is the only way in.
resource "aws_apigatewayv2_api" "api" {
  name                         = local.name
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true

  dynamic "cors_configuration" {
    for_each = length(var.cors_allow_origins) > 0 ? [1] : []

    content {
      allow_origins = var.cors_allow_origins
      allow_methods = ["*"]
      allow_headers = ["authorization", "content-type"]
      max_age       = 3600
    }
  }
}

resource "aws_apigatewayv2_integration" "function" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.function.id}"
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${local.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTimeEpoch"
      method             = "$context.httpMethod"
      path               = "$context.path"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      latency            = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      integrationError   = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
