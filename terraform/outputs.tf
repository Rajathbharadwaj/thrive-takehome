output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = local.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = local.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = local.subnet_ids
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = var.use_default_vpc ? data.aws_subnets.default_public[0].ids : module.vpc[0].public_subnets
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = local.ecr_repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = local.ecr_repository_arn
}

output "load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.load_balancer_controller_irsa_role.iam_role_arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = local.github_actions_role_arn
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = data.aws_secretsmanager_secret.app_secrets.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

# Configuration values for kubectl
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ECR login command
output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.ecr_repository_url}"
}

# Summary information
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    cluster_name        = module.eks.cluster_name
    cluster_endpoint    = module.eks.cluster_endpoint
    vpc_id             = local.vpc_id
    ecr_repository_url = local.ecr_repository_url
    region             = var.aws_region
    environment        = var.environment
  }
}
# Force refresh - Thu 14 Aug 2025 09:55:22 PM EDT
