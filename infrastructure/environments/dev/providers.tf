provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = "${var.application_name}-${var.environment}"
  common_tags = {
    Application = var.application_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "Elzabeth-L/Fitness_Tracker"
    CostCenter  = "learning"
  }
}
