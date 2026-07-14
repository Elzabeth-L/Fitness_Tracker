variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "application_name" {
  type    = string
  default = "fitness-tracker"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "image_uri" {
  description = "Immutable ECR image URI including sha256 digest."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image_uri))
    error_message = "image_uri must be an immutable ECR URI ending in @sha256:<64 hex characters>."
  }
}

variable "jwt_secret_arn" {
  description = "Bootstrap-managed Secrets Manager ARN containing the JWT signing key."
  type        = string
}

variable "mongodb_secret_arn" {
  description = "Bootstrap-managed transitional Secrets Manager ARN containing MONGODB_URI."
  type        = string
}

variable "lambda_memory_mb" {
  type    = number
  default = 512
}

variable "lambda_timeout_seconds" {
  type    = number
  default = 20
}

variable "lambda_reserved_concurrency" {
  type    = number
  default = 2
}

variable "api_throttling_rate_limit" {
  type    = number
  default = 2
}

variable "api_throttling_burst_limit" {
  type    = number
  default = 5
}

variable "log_retention_days" {
  type    = number
  default = 7
}
