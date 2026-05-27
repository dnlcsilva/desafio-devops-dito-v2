terraform {
  backend "s3" {
    bucket         = "dito-devops-terraform-state-staging"
    key            = "dito-api/staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dito-devops-terraform-locks-staging"
    encrypt        = true
  }
}
