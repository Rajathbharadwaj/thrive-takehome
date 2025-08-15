#!/bin/bash

# 🚀 Canary Deployment Test Script
# Quick commands for testing and demonstrating canary deployments

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

# Get ALB URL
get_alb_url() {
    kubectl get ingress hello-world-ingress -n thrive-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "ALB_URL_NOT_FOUND"
}

# Function to start port forwarding for dashboards
start_dashboards() {
    print_header "🎯 Starting Dashboard Port Forwarding"
    
    # Kill any existing port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Start port forwarding
    print_status "Starting Argo Rollouts dashboard..."
    kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100 > /dev/null 2>&1 &
    
    print_status "Starting Prometheus dashboard..."
    kubectl port-forward svc/prometheus-service -n monitoring 9090:9090 > /dev/null 2>&1 &
    
    print_status "Starting Grafana dashboard..."
    kubectl port-forward svc/grafana -n monitoring 3000:3000 > /dev/null 2>&1 &
    
    sleep 3
    
    print_success "Dashboards available at:"
    echo "🎯 Argo Rollouts: http://localhost:3100"
    echo "📊 Prometheus:    http://localhost:9090" 
    echo "📈 Grafana:       http://localhost:3000 (admin/admin)"
}

# Function to show current status
show_status() {
    print_header "📊 Current Deployment Status"
    
    echo "Rollout Status:"
    kubectl get rollouts -n thrive-app
    echo
    
    echo "Pods:"
    kubectl get pods -n thrive-app
    echo
    
    ALB_URL=$(get_alb_url)
    if [ "$ALB_URL" != "ALB_URL_NOT_FOUND" ]; then
        echo "Application URL: http://$ALB_URL"
        echo "Testing connection..."
        curl -s "http://$ALB_URL" | head -1 || echo "Connection failed"
    else
        print_error "ALB URL not found"
    fi
}

# Function to trigger canary deployment
trigger_canary() {
    print_header "🚀 Triggering Canary Deployment"
    
    IMAGE=${1:-"nginx:latest"}
    print_status "Deploying new image: $IMAGE"
    
    kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
        -p="{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"hello-world\",\"image\":\"$IMAGE\"}]}}}}"
    
    print_success "Canary deployment triggered!"
    print_status "Watch progress at: http://localhost:3100"
    
    # Monitor for a few seconds
    sleep 5
    kubectl get rollouts -n thrive-app
}

# Function to test traffic distribution
test_traffic() {
    print_header "🌐 Testing Traffic Distribution"
    
    ALB_URL=$(get_alb_url)
    if [ "$ALB_URL" == "ALB_URL_NOT_FOUND" ]; then
        print_error "ALB URL not found. Cannot test traffic."
        return 1
    fi
    
    print_status "Sending 20 requests to test traffic split..."
    
    OLD_COUNT=0
    NEW_COUNT=0
    
    for i in {1..20}; do
        RESPONSE=$(curl -s "http://$ALB_URL" || echo "ERROR")
        
        if [[ $RESPONSE == *"Hello World"* ]]; then
            OLD_COUNT=$((OLD_COUNT + 1))
            echo "Request $i: 🟢 OLD version (Node.js)"
        elif [[ $RESPONSE == *"nginx"* ]] || [[ $RESPONSE == *"Welcome to nginx"* ]]; then
            NEW_COUNT=$((NEW_COUNT + 1))
            echo "Request $i: 🔵 NEW version (nginx)"
        else
            echo "Request $i: ❓ UNKNOWN response"
        fi
        
        sleep 1
    done
    
    echo
    print_success "Traffic Distribution Results:"
    echo "🟢 Old version: $OLD_COUNT requests ($(( OLD_COUNT * 5 ))%)"
    echo "🔵 New version: $NEW_COUNT requests ($(( NEW_COUNT * 5 ))%)"
}

# Function to promote deployment
promote_deployment() {
    print_header "⚡ Promoting Deployment to 100%"
    
    kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
        -p='{"metadata":{"annotations":{"rollouts.argoproj.io/promote":"true"}}}'
    
    print_success "Deployment promoted!"
    sleep 3
    kubectl get rollouts -n thrive-app
}

# Function to rollback deployment
rollback_deployment() {
    print_header "🔄 Rolling Back Deployment"
    
    kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
        -p='{"metadata":{"annotations":{"rollouts.argoproj.io/abort":"true"}}}'
    
    print_success "Rollback initiated!"
    sleep 3
    kubectl get rollouts -n thrive-app
}

# Function to run full demo
run_demo() {
    print_header "🎭 Full Canary Deployment Demo"
    
    echo "This will demonstrate:"
    echo "1. Current state"
    echo "2. Canary deployment"
    echo "3. Traffic testing"
    echo "4. Rollback"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Demo cancelled."
        return 0
    fi
    
    # Step 1: Show current state
    show_status
    
    # Step 2: Start dashboards
    start_dashboards
    
    # Step 3: Trigger canary
    echo
    read -p "Press Enter to trigger canary deployment..."
    trigger_canary "nginx:latest"
    
    # Step 4: Test traffic
    echo
    print_status "Waiting 30 seconds for canary to start..."
    sleep 30
    test_traffic
    
    # Step 5: Demonstrate rollback
    echo
    read -p "Press Enter to demonstrate rollback..."
    rollback_deployment
    
    # Step 6: Final status
    echo
    print_status "Waiting for rollback to complete..."
    sleep 10
    show_status
    
    print_success "Demo completed! 🎉"
}

# Main menu
show_menu() {
    echo
    print_header "🚀 Canary Deployment Test Menu"
    echo "1. Show current status"
    echo "2. Start dashboards"
    echo "3. Trigger canary deployment"
    echo "4. Test traffic distribution"
    echo "5. Promote deployment"
    echo "6. Rollback deployment"
    echo "7. Run full demo"
    echo "8. Exit"
    echo
}

# Main script logic
if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Choose an option (1-8): " choice
        
        case $choice in
            1) show_status ;;
            2) start_dashboards ;;
            3) 
                read -p "Enter image name (default: nginx:latest): " image
                trigger_canary "${image:-nginx:latest}"
                ;;
            4) test_traffic ;;
            5) promote_deployment ;;
            6) rollback_deployment ;;
            7) run_demo ;;
            8) 
                print_success "Goodbye!"
                exit 0
                ;;
            *) 
                print_error "Invalid option. Please choose 1-8."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
else
    # Command line mode
    case $1 in
        "status") show_status ;;
        "dashboards") start_dashboards ;;
        "canary") trigger_canary "$2" ;;
        "traffic") test_traffic ;;
        "promote") promote_deployment ;;
        "rollback") rollback_deployment ;;
        "demo") run_demo ;;
        *)
            echo "Usage: $0 [status|dashboards|canary|traffic|promote|rollback|demo]"
            echo "Run without arguments for interactive mode."
            exit 1
            ;;
    esac
fi
