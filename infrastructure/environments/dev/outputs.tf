output "api_url" {
  value = "${aws_apigatewayv2_api.application.api_endpoint}/${aws_apigatewayv2_stage.dev.name}"
}

output "health_url" {
  value = "${aws_apigatewayv2_api.application.api_endpoint}/${aws_apigatewayv2_stage.dev.name}/health"
}

output "lambda_function_name" {
  value = aws_lambda_function.application.function_name
}

output "lambda_version" {
  value = aws_lambda_function.application.version
}

output "deployed_image_uri" {
  value = var.image_uri
}

output "mongodb_secret_arn" {
  description = "Bootstrap-managed transitional MongoDB secret container."
  value       = var.mongodb_secret_arn
}

output "jwt_secret_arn" {
  description = "Bootstrap-managed JWT signing secret container."
  value       = var.jwt_secret_arn
}

output "dynamodb_table_names" {
  value = {
    users    = aws_dynamodb_table.users.name
    workouts = aws_dynamodb_table.workouts.name
    metrics  = aws_dynamodb_table.metrics.name
    plans    = aws_dynamodb_table.plans.name
  }
}
