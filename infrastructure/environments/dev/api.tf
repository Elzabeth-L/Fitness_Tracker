resource "aws_apigatewayv2_api" "application" {
  name          = local.name_prefix
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "application" {
  api_id                 = aws_apigatewayv2_api.application.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_alias.dev.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.application.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.application.id}"
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.application.id
  name        = var.environment
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = false
    throttling_burst_limit   = var.api_throttling_burst_limit
    throttling_rate_limit    = var.api_throttling_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
    })
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.application.function_name
  qualifier     = aws_lambda_alias.dev.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.application.execution_arn}/*/*"
}
