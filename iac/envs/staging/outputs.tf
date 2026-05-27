output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "ecr_repository_url" { value = module.ecr.repository_url }
output "rds_endpoint" { value = module.rds.endpoint }
output "secret_name" { value = module.app_secret.secret_name }
output "workload_role_arn" { value = module.workload_iam.workload_role_arn }
