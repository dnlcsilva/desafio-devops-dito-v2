module "vpc" {
  source               = "../../modules/vpc"
  name                 = local.name
  cidr_block           = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = "${local.name}-eks"
  tags                 = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "${local.name}-api"
  tags   = local.common_tags
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = "${local.name}-eks"
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = local.common_tags
}

module "rds" {
  source                  = "../../modules/rds"
  name                    = "${local.name}-postgres"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_cidr_blocks     = var.private_subnet_cidrs
  db_name                 = "ditoapi"
  db_username             = var.db_username
  db_password             = var.db_password
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  tags                    = local.common_tags
}

module "app_secret" {
  source      = "../../modules/secrets"
  name        = "${local.name}/api/database"
  description = "Database credentials for Dito API ${var.environment}."
  secret_value = {
    DB_HOST     = module.rds.endpoint
    DB_PORT     = tostring(module.rds.port)
    DB_DATABASE = module.rds.db_name
    DB_USERNAME = var.db_username
    DB_PASSWORD = var.db_password
  }
  tags = local.common_tags
}

module "workload_iam" {
  source               = "../../modules/iam"
  name                 = "${local.name}-api-irsa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.cluster_oidc_issuer_url
  namespace            = local.app_namespace
  service_account_name = local.app_service_account_name
  secret_arn           = module.app_secret.secret_arn
  tags                 = local.common_tags
}
