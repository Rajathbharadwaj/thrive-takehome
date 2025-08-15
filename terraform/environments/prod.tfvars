# Production Environment Configuration
project_name = "thrive-takehome-final"
environment = "production"

# Production-grade resources
instance_type = "t3.medium"
desired_nodes = 3
min_nodes = 3
max_nodes = 5

# Production features enabled
enable_https = true  # HTTPS enabled for bonus requirement
domain_name = "thrive.docrag.io"  # Subdomain for the DevOps demo - keeps main site safe

# Shared configuration
aws_region = "us-east-1"
ecr_repository_name = "thrive-hello-world"
alert_email = "rajathdb@gmail.com"
github_repo = "Rajathbharadwaj/thrive-takehome"

# Production cluster name (keep existing to avoid recreation)
cluster_name = "thrive-prod-cluster-fresh"

# Simplified: No conditional logic needed for single production environment

# Use default VPC to avoid VPC limit issues
use_default_vpc = true