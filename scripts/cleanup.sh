#!/bin/bash

# 🧹 Cleanup Script - Remove dependencies before terraform destroy
# This prevents common terraform destroy failures
# 
# Usage: ./cleanup.sh [environment]
# Examples:
#   ./cleanup.sh          # Clean up main/production environment  
#   ./cleanup.sh dev      # Clean up dev environment
#   ./cleanup.sh all      # Clean up ALL failed deployments

set -e

# Environment detection
ENVIRONMENT=${1:-"production"}
if [ "$ENVIRONMENT" = "dev" ]; then
    PROJECT_TAG="thrive-takehome-dev"
    VPC_NAME_PATTERN="thrive-takehome-dev-vpc"
elif [ "$ENVIRONMENT" = "all" ]; then
    PROJECT_TAG="thrive*"
    VPC_NAME_PATTERN="thrive*"
else
    PROJECT_TAG="thrive-takehome"
    VPC_NAME_PATTERN="thrive-vpc"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${YELLOW}⏳ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Function to terminate instances and clean up failed VPCs
cleanup_failed_deployments() {
    print_header "🔥 Cleaning up Failed Deployments & VPCs"
    
    # Find all VPCs matching our pattern
    local vpc_ids=$(aws ec2 describe-vpcs \
                   --filters "Name=tag:Name,Values=$VPC_NAME_PATTERN" \
                   --query 'Vpcs[].VpcId' \
                   --output text 2>/dev/null || echo "")
    
    if [ -z "$vpc_ids" ]; then
        # If no VPCs with tags, check by name pattern for failed deployments
        vpc_ids=$(aws ec2 describe-vpcs \
                 --query "Vpcs[?contains(Tags[?Key=='Name'].Value, 'thrive')].VpcId" \
                 --output text 2>/dev/null || echo "")
    fi
    
    for vpc_id in $vpc_ids; do
        if [ "$vpc_id" = "None" ] || [ "$vpc_id" = "null" ] || [ -z "$vpc_id" ]; then
            continue
        fi
        
        print_status "Processing VPC: $vpc_id"
        
        # 1. Terminate all instances in this VPC
        local instance_ids=$(aws ec2 describe-instances \
                           --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running,stopped,stopping" \
                           --query 'Reservations[].Instances[].InstanceId' \
                           --output text 2>/dev/null || echo "")
        
        if [ -n "$instance_ids" ]; then
            print_status "Terminating instances in VPC $vpc_id: $instance_ids"
            aws ec2 terminate-instances --instance-ids $instance_ids >/dev/null 2>&1 || true
            
            print_status "Waiting for instances to terminate..."
            aws ec2 wait instance-terminated --instance-ids $instance_ids 2>/dev/null || true
            sleep 10
        fi
        
        # 2. Delete NAT Gateways
        local nat_gateway_ids=$(aws ec2 describe-nat-gateways \
                              --filter "Name=vpc-id,Values=$vpc_id" \
                              --query 'NatGateways[?State==`available`].NatGatewayId' \
                              --output text 2>/dev/null || echo "")
        
        if [ -n "$nat_gateway_ids" ]; then
            print_status "Deleting NAT Gateways in VPC $vpc_id"
            for nat_id in $nat_gateway_ids; do
                aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" >/dev/null 2>&1 || true
            done
            sleep 30
        fi
        
        # 3. Delete Internet Gateways
        local igw_ids=$(aws ec2 describe-internet-gateways \
                       --filters "Name=attachment.vpc-id,Values=$vpc_id" \
                       --query 'InternetGateways[].InternetGatewayId' \
                       --output text 2>/dev/null || echo "")
        
        if [ -n "$igw_ids" ]; then
            print_status "Detaching and deleting Internet Gateways in VPC $vpc_id"
            for igw_id in $igw_ids; do
                aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" 2>/dev/null || true
                aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" 2>/dev/null || true
            done
        fi
        
        # 4. Delete subnets
        local subnet_ids=$(aws ec2 describe-subnets \
                          --filters "Name=vpc-id,Values=$vpc_id" \
                          --query 'Subnets[].SubnetId' \
                          --output text 2>/dev/null || echo "")
        
        if [ -n "$subnet_ids" ]; then
            print_status "Deleting subnets in VPC $vpc_id"
            for subnet_id in $subnet_ids; do
                aws ec2 delete-subnet --subnet-id "$subnet_id" 2>/dev/null || true
            done
        fi
        
        # 5. Clean up security groups (except default)
        local sg_ids=$(aws ec2 describe-security-groups \
                      --filters "Name=vpc-id,Values=$vpc_id" \
                      --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
                      --output text 2>/dev/null || echo "")
        
        if [ -n "$sg_ids" ]; then
            print_status "Deleting security groups in VPC $vpc_id"
            for sg_id in $sg_ids; do
                aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null || true
            done
        fi
        
        # 6. Finally, try to delete the VPC
        print_status "Attempting to delete VPC: $vpc_id"
        aws ec2 delete-vpc --vpc-id "$vpc_id" 2>/dev/null || print_error "Failed to delete VPC $vpc_id (may have remaining dependencies)"
    done
    
    print_success "Failed deployment cleanup completed!"
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    print_header "🧹 Cleaning up Kubernetes resources"
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_status "No Kubernetes cluster found, skipping k8s cleanup"
        return 0
    fi
    
    print_status "Deleting application resources..."
    kubectl delete namespace thrive-app --timeout=60s >/dev/null 2>&1 || true
    
    print_status "Deleting monitoring resources..."
    kubectl delete namespace monitoring --timeout=60s >/dev/null 2>&1 || true
    
    print_status "Cleaning up Argo Rollouts CRDs..."
    kubectl delete crd analysisruns.argoproj.io >/dev/null 2>&1 || true
    kubectl delete crd analysistemplates.argoproj.io >/dev/null 2>&1 || true
    kubectl delete crd clusteranalysistemplates.argoproj.io >/dev/null 2>&1 || true
    kubectl delete crd experiments.argoproj.io >/dev/null 2>&1 || true
    kubectl delete crd rollouts.argoproj.io >/dev/null 2>&1 || true
    
    print_status "Waiting for resources to be deleted..."
    sleep 30
    
    print_success "Kubernetes cleanup completed!"
}

# Function to cleanup Load Balancers
cleanup_load_balancers() {
    print_header "🔗 Cleaning up Load Balancers"
    
    # Get VPC ID if exists
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=thrive-takehome" \
                   --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [ "$vpc_id" != "None" ] && [ "$vpc_id" != "null" ]; then
        print_status "Found VPC: $vpc_id"
        
        # Delete Load Balancers in this VPC
        local lb_arns=$(aws elbv2 describe-load-balancers \
                       --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" \
                       --output text 2>/dev/null || echo "")
        
        if [ -n "$lb_arns" ]; then
            print_status "Deleting Load Balancers..."
            for lb_arn in $lb_arns; do
                aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" 2>/dev/null || true
            done
            
            print_status "Waiting for Load Balancers to be deleted..."
            sleep 60
        fi
    fi
    
    print_success "Load Balancer cleanup completed!"
}

# Function to cleanup ENIs
cleanup_network_interfaces() {
    print_header "🌐 Cleaning up Network Interfaces & Security Groups"
    
    # Get VPC ID if exists
    local vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=thrive-takehome" \
                   --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [ "$vpc_id" != "None" ] && [ "$vpc_id" != "null" ]; then
        print_status "Cleaning up resources in VPC: $vpc_id"
        
        # Clean up ALL ENIs in this VPC (not just available ones)
        print_status "Finding all ENIs in VPC..."
        local all_eni_ids=$(aws ec2 describe-network-interfaces \
                           --filters "Name=vpc-id,Values=$vpc_id" \
                           --query 'NetworkInterfaces[].NetworkInterfaceId' \
                           --output text 2>/dev/null || echo "")
        
        if [ -n "$all_eni_ids" ]; then
            print_status "Detaching and deleting ENIs..."
            for eni_id in $all_eni_ids; do
                # Force detach if attached
                aws ec2 detach-network-interface --network-interface-id "$eni_id" --force 2>/dev/null || true
                sleep 2
                # Delete the ENI
                aws ec2 delete-network-interface --network-interface-id "$eni_id" 2>/dev/null || true
            done
        fi
        
        # Clean up security groups (except default)
        print_status "Cleaning up security groups..."
        local sg_ids=$(aws ec2 describe-security-groups \
                      --filters "Name=vpc-id,Values=$vpc_id" \
                      --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
                      --output text 2>/dev/null || echo "")
        
        if [ -n "$sg_ids" ]; then
            for sg_id in $sg_ids; do
                # Remove all rules first
                aws ec2 revoke-security-group-ingress --group-id "$sg_id" --source-group "$sg_id" 2>/dev/null || true
                aws ec2 revoke-security-group-egress --group-id "$sg_id" --source-group "$sg_id" 2>/dev/null || true
                # Delete the security group
                aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null || true
            done
        fi
        
        # Clean up route tables (except main)
        print_status "Cleaning up route tables..."
        local rt_ids=$(aws ec2 describe-route-tables \
                      --filters "Name=vpc-id,Values=$vpc_id" \
                      --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
                      --output text 2>/dev/null || echo "")
        
        if [ -n "$rt_ids" ]; then
            for rt_id in $rt_ids; do
                aws ec2 delete-route-table --route-table-id "$rt_id" 2>/dev/null || true
            done
        fi
    fi
    
    print_success "Network cleanup completed!"
}

# Function to cleanup ECR repository
cleanup_ecr() {
    print_header "📦 Cleaning up ECR Repository"
    
    local repo_name="thrive-hello-world"
    
    if aws ecr describe-repositories --repository-names "$repo_name" >/dev/null 2>&1; then
        print_status "Deleting ECR repository: $repo_name"
        aws ecr delete-repository --repository-name "$repo_name" --force >/dev/null 2>&1 || true
        print_success "ECR repository deleted!"
    else
        print_status "ECR repository not found, skipping"
    fi
}

# Function to wait and retry cleanup
wait_and_retry() {
    print_header "⏳ Waiting for AWS resources to stabilize"
    
    print_status "Waiting 60 seconds for all deletions to propagate..."
    sleep 60
    
    print_success "Ready for terraform destroy!"
}

# Main cleanup function
main() {
    print_header "🧹 Starting Cleanup Process - Environment: $ENVIRONMENT"
    
    echo "This script will clean up resources before terraform destroy"
    echo "to prevent dependency errors."
    echo ""
    
    # Clean up failed deployments first (handles VPC limit issues)
    if [ "$ENVIRONMENT" = "all" ] || [ "$ENVIRONMENT" = "dev" ]; then
        cleanup_failed_deployments
    fi
    
    cleanup_kubernetes
    cleanup_load_balancers  
    cleanup_network_interfaces
    cleanup_ecr
    wait_and_retry
    
    print_success "🎉 Cleanup completed successfully!"
    echo ""
    echo "Now you can run:"
    if [ "$ENVIRONMENT" = "dev" ]; then
        echo "  cd terraform && terraform workspace select dev && terraform destroy -var-file=environments/dev.tfvars -auto-approve"
    else
        echo "  cd terraform && terraform destroy -auto-approve"
    fi
}

# Run main function
main "$@"
