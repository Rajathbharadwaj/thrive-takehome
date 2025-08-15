#!/bin/bash

# 🌍 Multi-Environment Deployment Script
# Deploy to dev or production environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_status() {
    echo -e "${YELLOW}⏳ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment> [action]"
    echo ""
    echo "Environments:"
    echo "  dev      - Development environment (t3.micro, 1 node)"
    echo "  prod     - Production environment (t3.medium, 3 nodes)"
    echo ""
    echo "Actions:"
    echo "  plan     - Show what would be deployed (default)"
    echo "  apply    - Deploy the environment"
    echo "  destroy  - Destroy the environment"
    echo ""
    echo "Examples:"
    echo "  $0 dev plan      # Plan dev environment"
    echo "  $0 dev apply     # Deploy dev environment"
    echo "  $0 prod destroy  # Destroy production"
}

# Validate environment
validate_environment() {
    local env=$1
    
    if [[ ! "$env" =~ ^(dev|prod)$ ]]; then
        print_error "Invalid environment: $env"
        show_usage
        exit 1
    fi
    
    if [[ ! -f "terraform/environments/${env}.tfvars" ]]; then
        print_error "Environment file not found: terraform/environments/${env}.tfvars"
        exit 1
    fi
}

# Deploy environment
deploy_environment() {
    local env=$1
    local action=$2
    
    print_header "🌍 ${env^^} Environment - ${action^^}"
    
    # Change to terraform directory
    cd terraform
    
    # Initialize terraform
    print_status "Initializing Terraform..."
    terraform init >/dev/null
    
    # Set workspace (optional - for better state isolation)
    print_status "Setting up workspace for $env..."
    terraform workspace select "$env" 2>/dev/null || terraform workspace new "$env"
    
    case $action in
        "plan")
            print_status "Planning $env environment..."
            terraform plan -var-file="environments/${env}.tfvars"
            ;;
        "apply")
            # First, ensure shared resources exist
            print_status "Ensuring shared resources exist..."
            terraform plan -target=aws_ecr_repository.app -target=aws_iam_openid_connect_provider.github -target=aws_iam_role.github_actions -var-file="environments/${env}.tfvars" -out="shared.tfplan"
            terraform apply "shared.tfplan"
            rm -f "shared.tfplan"
            
            # Then deploy environment-specific resources
            print_status "Deploying $env environment..."
            terraform plan -var-file="environments/${env}.tfvars" -out="${env}.tfplan"
            
            echo ""
            print_status "Review the plan above. Continue? (y/N):"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                terraform apply "${env}.tfplan"
                rm -f "${env}.tfplan"
                print_success "$env environment deployed successfully!"
                
                # Show environment info
                print_header "🌍 $env Environment Information"
                echo "Cluster: $(terraform output -raw cluster_name 2>/dev/null || echo 'Not available')"
                echo "VPC: $(terraform output -raw vpc_id 2>/dev/null || echo 'Not available')"
                echo ""
                echo "To configure kubectl:"
                echo "aws eks update-kubeconfig --region $(terraform output -raw aws_region 2>/dev/null || echo 'us-east-1') --name $(terraform output -raw cluster_name 2>/dev/null || echo 'cluster-name')"
            else
                print_status "Deployment cancelled."
                rm -f "${env}.tfplan"
            fi
            ;;
        "destroy")
            print_status "Planning destruction of $env environment..."
            terraform plan -destroy -var-file="environments/${env}.tfvars"
            
            echo ""
            print_error "⚠️  This will DESTROY the entire $env environment!"
            print_status "Are you sure you want to continue? Type 'destroy' to confirm:"
            read -r response
            if [[ "$response" == "destroy" ]]; then
                terraform destroy -var-file="environments/${env}.tfvars" -auto-approve
                print_success "$env environment destroyed successfully!"
            else
                print_status "Destruction cancelled."
            fi
            ;;
        *)
            print_error "Invalid action: $action"
            show_usage
            exit 1
            ;;
    esac
}

# Main function
main() {
    local env=${1:-}
    local action=${2:-plan}
    
    if [[ -z "$env" ]]; then
        print_error "Environment is required"
        show_usage
        exit 1
    fi
    
    validate_environment "$env"
    deploy_environment "$env" "$action"
}

# Run main function
main "$@"
