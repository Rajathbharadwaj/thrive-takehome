# Development Environment Configuration
project_name     = "thrive-takehome-dev"
environment      = "dev"
aws_region       = "us-east-1"

# Smaller resources for dev
instance_types = ["t3.micro"]
desired_size   = 1
max_size       = 2
min_size       = 1

# Development settings
alert_email = "rajathdb@gmail.com"
github_repo = "Rajathbharadwaj/thrive-takehome"
ecr_repository_name = "thrive-hello-world"

# Variable mapping for Terraform
instance_type = "t3.micro"
desired_nodes = 1
min_nodes = 1
max_nodes = 2

# Cost optimization for dev
enable_monitoring = false  # Skip expensive monitoring in dev
enable_https = false       # Skip HTTPS in dev
