locals {
  runtime_secret_arns = compact([
    var.jwt_secret_arn,
    var.mongodb_secret_arn
  ])
}
