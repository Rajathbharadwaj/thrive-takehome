#!/bin/bash

# 📊 Simple Dashboard Starter
# Starts all monitoring dashboards with port forwarding

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

# Function to check if pod exists
check_service() {
    local namespace=$1
    local service=$2
    kubectl get svc "$service" -n "$namespace" >/dev/null 2>&1
}

# Main function
start_dashboards() {
    print_header "📊 Starting All Monitoring Dashboards"
    
    # Kill any existing port forwards
    print_status "Stopping any existing port forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Start Argo Rollouts Dashboard
    if check_service "argo-rollouts" "argo-rollouts-dashboard"; then
        print_status "Starting Argo Rollouts dashboard..."
        kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100 >/dev/null 2>&1 &
        ARGO_PID=$!
        print_success "Argo Rollouts: http://localhost:3100"
    else
        print_error "Argo Rollouts dashboard service not found"
    fi
    
    # Start Prometheus
    if check_service "monitoring" "prometheus-service"; then
        print_status "Starting Prometheus..."
        kubectl port-forward svc/prometheus-service -n monitoring 9090:9090 >/dev/null 2>&1 &
        PROM_PID=$!
        print_success "Prometheus: http://localhost:9090"
    else
        print_error "Prometheus service not found"
    fi
    
    # Start Grafana  
    if check_service "monitoring" "grafana"; then
        print_status "Starting Grafana..."
        kubectl port-forward svc/grafana -n monitoring 3000:3000 >/dev/null 2>&1 &
        GRAFANA_PID=$!
        print_success "Grafana: http://localhost:3000 (admin/admin)"
    else
        print_error "Grafana service not found"
    fi
    
    sleep 3
    
    print_header "🎉 Dashboard URLs Ready!"
    echo "🎯 Argo Rollouts: http://localhost:3100  (Canary deployments)"
    echo "📊 Prometheus:    http://localhost:9090  (Raw metrics)"  
    echo "📈 Grafana:       http://localhost:3000  (Beautiful dashboards)"
    echo ""
    echo "💡 Pro Tips:"
    echo "   • Try these Prometheus queries: up, http_requests_total, rate(http_requests_total[5m])"
    echo "   • Grafana login: admin/admin"
    echo "   • Press Ctrl+C to stop all port forwarding"
    echo ""
    
    # Wait for user to stop
    print_status "Press Ctrl+C to stop all dashboards..."
    
    # Trap Ctrl+C to clean up
    trap 'echo ""; print_status "Stopping dashboards..."; kill $ARGO_PID $PROM_PID $GRAFANA_PID 2>/dev/null || true; print_success "All dashboards stopped!"; exit 0' INT
    
    # Keep script running
    while true; do
        sleep 1
    done
}

# Run the function
start_dashboards
