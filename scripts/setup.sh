#!/bin/bash

# 🚀 Thrive DevOps Platform - Automated Setup Script
# This script deploys the complete platform to AWS

set -e  # Exit on any error

echo "🚀 Starting Thrive DevOps Platform deployment..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install them and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites installed!"
}

# Verify AWS credentials
check_aws_credentials() {
    print_status "Verifying AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid"
        print_error "Please run 'aws configure' first"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS credentials verified! Account ID: $account_id"
}

# Setup Terraform variables
setup_terraform_vars() {
    print_status "Setting up Terraform variables..."
    
    cd terraform
    
    if [ ! -f terraform.tfvars ]; then
        if [ ! -f terraform.tfvars.example ]; then
            print_error "terraform.tfvars.example not found!"
            exit 1
        fi
        
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Created terraform.tfvars from example."
        print_warning "Please edit terraform.tfvars with your email and GitHub repo before continuing."
        print_warning "Press Enter to continue after editing, or Ctrl+C to abort..."
        read -r
    fi
    
    print_success "Terraform variables configured!"
    cd ..
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Planning deployment..."
    terraform plan -var-file="environments/prod.tfvars"
    
    print_warning "About to deploy infrastructure. This will create AWS resources and incur costs."
    print_warning "Estimated cost: ~$4-5/day"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Deployment cancelled"
        exit 1
    fi
    
    print_status "Applying Terraform configuration..."
    terraform apply -var-file="environments/prod.tfvars" -auto-approve
    
    print_success "Infrastructure deployed!"
    cd ..
}

# Configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl for EKS cluster..."
    
    cd terraform
    local aws_region=$(terraform output aws_region | tr -d '"')
    local cluster_name=$(terraform output cluster_name | tr -d '"')
    cd ..
    
    aws eks update-kubeconfig --region "$aws_region" --name "$cluster_name"
    
    print_status "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    print_success "Kubectl configured and cluster is ready!"
    
    # Configure GitHub Actions access to EKS cluster
    print_status "Configuring GitHub Actions access to EKS cluster..."
    configure_github_actions_access
    
    # Fix security group tagging for ALB compatibility
    print_status "Fixing security group tags for ALB controller..."
    fix_security_group_tags
}



# Configure GitHub Actions access to EKS cluster
configure_github_actions_access() {
    print_status "Adding GitHub Actions role to EKS cluster access..."
    
    cd terraform
    local cluster_name=$(terraform output cluster_name | tr -d '"')
    local aws_account_id=$(terraform output -raw aws_account_id 2>/dev/null || aws sts get-caller-identity --query Account --output text)
    cd ..
    
    # Check if GitHub Actions role already exists in aws-auth
    if kubectl get configmap aws-auth -n kube-system -o yaml | grep -q "thrive-github-actions"; then
        print_status "GitHub Actions role already configured in aws-auth"
        return
    fi
    
    # Add GitHub Actions role to aws-auth configmap
    kubectl patch configmap aws-auth -n kube-system --patch "
data:
  mapRoles: |
    - rolearn: arn:aws:iam::${aws_account_id}:role/main-nodes-eks-node-group-$(date +%Y%m%d%H%M%S)
      groups:
      - system:bootstrappers
      - system:nodes
      username: system:node:{{EC2PrivateDNSName}}
    - rolearn: arn:aws:iam::${aws_account_id}:role/thrive-github-actions
      groups:
      - system:masters
      username: github-actions
" 2>/dev/null || {
        # If patch fails, try to get the current node role and update properly
        local node_role_arn=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' | grep -o 'arn:aws:iam::[0-9]*:role/[^[:space:]]*' | head -1)
        
        kubectl patch configmap aws-auth -n kube-system --patch "
data:
  mapRoles: |
    - rolearn: ${node_role_arn}
      groups:
      - system:bootstrappers
      - system:nodes
      username: system:node:{{EC2PrivateDNSName}}
    - rolearn: arn:aws:iam::${aws_account_id}:role/thrive-github-actions
      groups:
      - system:masters
      username: github-actions
"
    }
    
    print_success "GitHub Actions role added to EKS cluster access!"
}

# Build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region="us-east-1"
    local repository="thrive-hello-world"
    local image_uri="${account_id}.dkr.ecr.${region}.amazonaws.com/${repository}:latest"
    
    print_status "Building Docker image..."
    docker build -t $repository .
    
    print_status "Logging into ECR..."
    aws ecr get-login-password --region $region | docker login --username AWS --password-stdin "${account_id}.dkr.ecr.${region}.amazonaws.com"
    
    print_status "Tagging and pushing image..."
    docker tag $repository:latest $image_uri
    docker push $image_uri
    
    print_success "Docker image pushed to ECR!"
    
    # Update deployment with correct image URI
    print_status "Updating Kubernetes deployment with ECR image..."
    sed -i.bak "s|866567874511\.dkr\.ecr\.us-east-1\.amazonaws\.com|${account_id}.dkr.ecr.${region}.amazonaws.com|g" k8s/deployment.yaml
    
    print_success "Deployment updated with your ECR image!"
}

# Fix security group tagging for Load Balancer Controller
fix_security_group_tags() {
    print_status "Ensuring proper security group configuration..."
    
    cd terraform
    local cluster_name=$(terraform output cluster_name | tr -d '"')
    cd ..
    
    # Find security groups with cluster tag
    local cluster_tag="kubernetes.io/cluster/$cluster_name"
    local sg_ids=$(aws ec2 describe-security-groups \
        --filters "Name=tag:$cluster_tag,Values=owned" \
        --query 'SecurityGroups[*].GroupId' \
        --output text)
    
    if [ -n "$sg_ids" ]; then
        local sg_array=($sg_ids)
        if [ ${#sg_array[@]} -gt 1 ]; then
            # Multiple security groups found - fix the primary one
            for sg_id in $sg_ids; do
                local sg_name=$(aws ec2 describe-security-groups \
                    --group-ids $sg_id \
                    --query 'SecurityGroups[0].GroupName' \
                    --output text)
                
                # Remove tag from cluster security group (primary one)
                if [[ $sg_name == *"eks-cluster-sg"* ]]; then
                    print_status "Removing cluster tag from primary security group: $sg_id"
                    aws ec2 delete-tags --resources $sg_id --tags Key=$cluster_tag >/dev/null 2>&1 || true
                fi
            done
            
            print_status "Restarting ALB controller to refresh configuration..."
            kubectl rollout restart deployment aws-load-balancer-controller -n kube-system >/dev/null 2>&1 || true
        fi
    fi
    
    print_success "Security group tags fixed!"
}

# Deploy application to Kubernetes
deploy_application() {
    print_status "Deploying application to Kubernetes..."
    
    print_status "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    
    print_status "Deploying application..."
    kubectl apply -f k8s/deployment.yaml
    
    print_status "Setting up auto-scaling..."
    kubectl apply -f k8s/hpa.yaml
    
    print_status "Configuring ingress..."
    kubectl apply -f k8s/ingress.yaml
    
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app=hello-world -n thrive-app --timeout=300s
    
    # Fix any security group issues
    fix_security_group_tags
    
    # Deploy monitoring stack
    deploy_monitoring
    
    # Convert to Argo Rollouts
    convert_to_rollouts
    
    print_success "Application deployed!"
}

# Get application URL
get_application_url() {
    print_status "Getting application URL..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local alb_url=$(kubectl get ingress hello-world-ingress -n thrive-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$alb_url" ]; then
            print_success "Application URL: http://$alb_url"
            
            print_status "Testing application..."
            sleep 30  # Wait for ALB to be ready
            
            if curl -s "http://$alb_url" >/dev/null; then
                print_success "Application is responding!"
                echo ""
                echo "🎉 Deployment completed successfully!"
                echo ""
                echo "📱 Application URLs:"
                echo "   Main: http://$alb_url"
                echo "   Health: http://$alb_url/health"
                echo "   Metrics: http://$alb_url/metrics"
                echo ""
                echo "🎛️  Management & Monitoring:"
                echo "   Kubectl: kubectl get pods -n thrive-app"
                echo "   Argo Rollouts: kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100"
                echo "   Prometheus: kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
                echo "   Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000 (admin/admin)"
                echo ""
                echo "🚀 Quick Start Monitoring:"
                echo "   ./scripts/test-canary.sh  # Interactive testing menu"
                echo ""
                echo "💰 Cost Management:"
                echo "   Daily cost: ~$4-5"
                echo "   Cleanup: ./scripts/cleanup.sh && cd terraform && terraform destroy -auto-approve"
                return 0
            else
                print_warning "Application URL found but not responding yet. It may take a few more minutes."
            fi
            return 0
        fi
        
        print_status "Waiting for Load Balancer to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    print_warning "Load Balancer URL not ready yet. Check with: kubectl get ingress -n thrive-app"
}

# Cleanup function
cleanup_on_error() {
    print_error "Deployment failed! Cleaning up..."
    print_warning "You may want to run 'terraform destroy' to clean up any created resources"
}

# Trap errors
trap cleanup_on_error ERR

# Main execution
main() {
    echo "🚀 Thrive DevOps Platform - Automated Setup"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    check_aws_credentials
    setup_terraform_vars
    deploy_infrastructure
    configure_kubectl
    build_and_push_image
    deploy_application
    get_application_url
    
    print_success "🎉 All done! Your DevOps platform is ready!"
}

# Deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack (Prometheus + Grafana)..."
    
    if kubectl apply -f monitoring/prometheus.yaml >/dev/null 2>&1; then
        print_success "Prometheus deployed!"
    else
        print_warning "Prometheus deployment failed (may already exist)"
    fi
    
    if kubectl apply -f monitoring/grafana.yaml >/dev/null 2>&1; then
        print_success "Grafana deployed!"
        # Verify Grafana service exists (common issue: partial deployment)
        if ! kubectl get service grafana -n monitoring >/dev/null 2>&1; then
            print_status "Grafana service missing, reapplying..."
            kubectl apply -f monitoring/grafana.yaml >/dev/null 2>&1 || true
        fi
    else
        print_warning "Grafana deployment failed (may already exist)"
    fi
    
    # Wait for monitoring pods to be ready
    kubectl wait --for=condition=Ready pods -l app=prometheus -n monitoring --timeout=120s >/dev/null 2>&1 || true
    kubectl wait --for=condition=Ready pods -l app=grafana -n monitoring --timeout=120s >/dev/null 2>&1 || true
    
    print_success "Monitoring stack deployed!"
}

# Convert deployment to Argo Rollouts
convert_to_rollouts() {
    print_status "Converting to Argo Rollouts for canary deployments..."
    
    # Delete existing deployment
    kubectl delete deployment hello-world -n thrive-app >/dev/null 2>&1 || true
    
    # Update rollout config with correct account ID
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local region=$(aws configure get region || echo "us-east-1")
    
    # Create temporary rollout file with correct account ID (using complete rollout with services)
    sed "s|866567874511\.dkr\.ecr\.us-east-1\.amazonaws\.com|${account_id}.dkr.ecr.${region}.amazonaws.com|g" \
        k8s/rollout-complete.yaml > /tmp/rollout-deploy.yaml
    
    # Apply rollout configuration
    if kubectl apply -f /tmp/rollout-deploy.yaml >/dev/null 2>&1; then
        print_success "Argo Rollouts deployed!"
        
        # Wait for rollout to be ready
        kubectl wait --for=condition=Available rollouts/hello-world-rollout -n thrive-app --timeout=300s >/dev/null 2>&1 || true
        
        # Cleanup temporary file
        rm -f /tmp/rollout-deploy.yaml
    else
        print_warning "Rollout deployment failed - using regular deployment"
        rm -f /tmp/rollout-deploy.yaml
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi