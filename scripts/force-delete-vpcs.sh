#!/bin/bash

# 🔥 Force Delete All Thrive VPCs Script
# This script systematically removes all dependencies and deletes VPCs

set -e

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

# VPCs to delete
VPCS=("vpc-05f264b707d6fa70e" "vpc-070380bbe0aa78d3d" "vpc-09515ce81ae5a4058")

print_header "🔥 Force Deleting All Thrive VPCs"

for vpc_id in "${VPCS[@]}"; do
    print_header "Processing VPC: $vpc_id"
    
    # Step 1: Delete NAT Gateways
    print_status "Checking for NAT Gateways..."
    nat_gateways=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text)
    if [ -n "$nat_gateways" ]; then
        print_status "Deleting NAT Gateways: $nat_gateways"
        for nat_id in $nat_gateways; do
            aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" 2>/dev/null && print_success "Deleted NAT Gateway $nat_id" || print_error "Failed to delete NAT Gateway $nat_id"
        done
        print_status "Waiting 30 seconds for NAT Gateways to delete..."
        sleep 30
    else
        print_success "No NAT Gateways found"
    fi
    
    # Step 2: Delete Network Interfaces
    print_status "Checking for Network Interfaces..."
    eni_ids=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)
    if [ -n "$eni_ids" ]; then
        print_status "Deleting Network Interfaces: $eni_ids"
        for eni_id in $eni_ids; do
            # Force detach first
            aws ec2 detach-network-interface --network-interface-id "$eni_id" --force 2>/dev/null || true
            sleep 2
            aws ec2 delete-network-interface --network-interface-id "$eni_id" 2>/dev/null && print_success "Deleted ENI $eni_id" || print_error "Failed to delete ENI $eni_id"
        done
    else
        print_success "No Network Interfaces found"
    fi
    
    # Step 3: Delete Internet Gateways
    print_status "Checking for Internet Gateways..."
    igw_ids=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text)
    if [ -n "$igw_ids" ]; then
        print_status "Detaching and deleting Internet Gateways: $igw_ids"
        for igw_id in $igw_ids; do
            aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" 2>/dev/null || true
            aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" 2>/dev/null && print_success "Deleted IGW $igw_id" || print_error "Failed to delete IGW $igw_id"
        done
    else
        print_success "No Internet Gateways found"
    fi
    
    # Step 4: Delete Subnets
    print_status "Checking for Subnets..."
    subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
    if [ -n "$subnet_ids" ]; then
        print_status "Deleting Subnets: $subnet_ids"
        for subnet_id in $subnet_ids; do
            aws ec2 delete-subnet --subnet-id "$subnet_id" 2>/dev/null && print_success "Deleted Subnet $subnet_id" || print_error "Failed to delete Subnet $subnet_id"
        done
    else
        print_success "No Subnets found"
    fi
    
    # Step 5: Delete Security Groups (except default)
    print_status "Checking for Security Groups..."
    sg_ids=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    if [ -n "$sg_ids" ]; then
        print_status "Deleting Security Groups: $sg_ids"
        for sg_id in $sg_ids; do
            # Remove all rules first
            aws ec2 revoke-security-group-ingress --group-id "$sg_id" --source-group "$sg_id" 2>/dev/null || true
            aws ec2 revoke-security-group-egress --group-id "$sg_id" --source-group "$sg_id" 2>/dev/null || true
            aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null && print_success "Deleted Security Group $sg_id" || print_error "Failed to delete Security Group $sg_id"
        done
    else
        print_success "No Security Groups found"
    fi
    
    # Step 6: Delete Route Tables (except main)
    print_status "Checking for Route Tables..."
    rt_ids=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    if [ -n "$rt_ids" ]; then
        print_status "Deleting Route Tables: $rt_ids"
        for rt_id in $rt_ids; do
            aws ec2 delete-route-table --route-table-id "$rt_id" 2>/dev/null && print_success "Deleted Route Table $rt_id" || print_error "Failed to delete Route Table $rt_id"
        done
    else
        print_success "No Route Tables found"
    fi
    
    # Step 7: Wait for everything to settle
    print_status "Waiting 10 seconds for resources to be fully deleted..."
    sleep 10
    
    # Step 8: Delete VPC
    print_status "Attempting to delete VPC: $vpc_id"
    if aws ec2 delete-vpc --vpc-id "$vpc_id" 2>/dev/null; then
        print_success "Successfully deleted VPC: $vpc_id"
    else
        print_error "Failed to delete VPC: $vpc_id (may still have hidden dependencies)"
    fi
    
    echo ""
done

print_header "🎉 VPC Cleanup Complete"
print_status "Checking final VPC count..."
vpc_count=$(aws ec2 describe-vpcs --query 'length(Vpcs)')
echo "Remaining VPCs: $vpc_count"

print_success "VPC cleanup script completed!"
