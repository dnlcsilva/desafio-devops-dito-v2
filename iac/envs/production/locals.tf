locals {
  name = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Challenge   = "dito-devops"
  }
  app_namespace            = "dito-api"
  app_service_account_name = "dito-api"
}
