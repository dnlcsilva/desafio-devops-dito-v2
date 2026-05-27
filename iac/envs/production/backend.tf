terraform {
  backend "s3" {
    bucket         = "dito-devops-terraform-state-production"
    key            = "dito-api/production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dito-devops-terraform-locks-production"
    encrypt        = true
  }
}
