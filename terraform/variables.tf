variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "thrive"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "thrive-prod-cluster-fresh"
}

variable "use_default_vpc" {
  description = "Whether to use the default VPC instead of creating a new one"
  type        = bool
  default     = false
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "rajath"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (cost optimization)"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}



variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "thrive-hello-world"
}

variable "create_shared_resources" {
  description = "Whether to create shared resources (ECR, OIDC, GitHub role) or use existing ones"
  type        = bool
  default     = false  # Default to using existing resources
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = "rajath@example.com"
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo' for OIDC"
  type        = string
  default     = "rajathbharadwaj/thrive-takehome"
}

variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS with cert-manager"
  type        = bool
  default     = false
}

# EKS Node Group Variables
variable "desired_nodes" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 3
}

variable "desired_size" {
  description = "Desired number of nodes (alias for desired_nodes)"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of nodes (alias for min_nodes)"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes (alias for max_nodes)"
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "Instance type for the EKS node group (single type)"
  type        = string
  default     = "t3.medium"
}

variable "instance_types" {
  description = "List of instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}
