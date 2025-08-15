terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  common_tags = {
    Project     = "thrive-takehome"
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# Data source for default VPC (when use_default_vpc = true)
data "aws_vpc" "default" {
  count   = var.use_default_vpc ? 1 : 0
  default = true
}

data "aws_subnets" "default_public" {
  count = var.use_default_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Filter subnets to exclude unsupported AZs for EKS
data "aws_subnet" "default_subnet_details" {
  count = var.use_default_vpc ? length(data.aws_subnets.default_public[0].ids) : 0
  id    = data.aws_subnets.default_public[0].ids[count.index]
}

# VPC Module (only when not using default VPC)
module "vpc" {
  count   = var.use_default_vpc ? 0 : 1
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # EKS specific tags
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    "kubernetes.io/role/elb"                            = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                   = "1"
  }

  tags = local.common_tags
}

# Local values for VPC selection  
locals {
  # EKS supported subnets (exclude 'e' AZ which is not supported)
  eks_supported_subnets = var.use_default_vpc ? [
    for subnet in data.aws_subnet.default_subnet_details : subnet.id
    if !endswith(subnet.availability_zone, "e")
  ] : []

  vpc_id              = var.use_default_vpc ? data.aws_vpc.default[0].id : module.vpc[0].vpc_id
  subnet_ids          = var.use_default_vpc ? local.eks_supported_subnets : module.vpc[0].private_subnets
  vpc_cidr_block      = var.use_default_vpc ? data.aws_vpc.default[0].cidr_block : module.vpc[0].vpc_cidr_block
  
  # Resource references
  ecr_repository_url        = aws_ecr_repository.app.repository_url
  ecr_repository_arn        = aws_ecr_repository.app.arn
  github_actions_role_arn   = data.aws_iam_role.github_actions.arn
}

# EKS Module
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                          = local.vpc_id
  subnet_ids                      = local.subnet_ids
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = var.instance_types
    
    attach_cluster_primary_security_group = true
    
    # Ensure sufficient IP addresses
    vpc_security_group_ids = [aws_security_group.additional.id]
  }

  eks_managed_node_groups = {
    main = {
      name = "main-nodes"
      
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      instance_types = var.instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      taints = []

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }

  # OIDC Identity provider
  cluster_identity_providers = {
    sts = {
      client_id = "sts.amazonaws.com"
    }
  }

  tags = local.common_tags
}

# Additional security group for EKS nodes
resource "aws_security_group" "additional" {
  name_prefix = "${var.project_name}-additional"
  vpc_id      = local.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
    description = "SSH access from VPC"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-additional-sg"
  })
}

# Create ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

# Use existing OIDC Provider for GitHub Actions
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Use existing IAM Role for GitHub Actions
data "aws_iam_role" "github_actions" {
  name = "thrive-github-actions"
}

# AWS Load Balancer Controller IAM
module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

# Use existing Secrets Manager secret
data "aws_secretsmanager_secret" "app_secrets" {
  name = "thrive-takehome-final-app-secrets"
}

resource "random_string" "api_key" {
  length  = 32
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS cluster CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = module.eks.cluster_name
  }

  tags = local.common_tags
}


