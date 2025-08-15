# 🚀 Canary Deployment Testing Guide

This guide demonstrates the canary deployment capabilities of the DevOps platform.

## 📋 Prerequisites

Ensure your deployment is running:
```bash
# Check rollout status
kubectl get rollouts -n thrive-app

# Check pods
kubectl get pods -n thrive-app

# Verify application is accessible
curl http://YOUR_ALB_URL
```

## 🎯 Access Monitoring Dashboards

Start all monitoring dashboards:
```bash
./scripts/start-dashboards.sh
```

**Available Dashboards:**
- 🎯 **Argo Rollouts**: http://localhost:3100 (canary deployment status)
- 📊 **Prometheus**: http://localhost:9090 (metrics collection)
- 📈 **Grafana**: http://localhost:3000 (admin/admin123 - visualization)

## 🧪 Testing Canary Deployments

### 1. Trigger a Canary Deployment

Update the application image to trigger a canary rollout:
```bash
# Change to nginx to see a visible difference
kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
  -p='{"spec":{"template":{"spec":{"containers":[{"name":"hello-world","image":"nginx:latest"}]}}}}'
```

**Watch the rollout progress:**
```bash
# Monitor in terminal
kubectl argo rollouts get rollout hello-world-rollout -n thrive-app --watch

# Or view in Argo Dashboard at http://localhost:3100
```

### 2. Observe Traffic Splitting

The canary deployment will progress through these stages:
- **25%** traffic to new version (30s pause)
- **50%** traffic to new version (60s pause)  
- **75%** traffic to new version (30s pause)
- **100%** traffic to new version (complete)

### 3. Test Traffic Distribution

Generate test traffic to see the split:
```bash
# Test multiple requests to see both versions
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://YOUR_ALB_URL | head -1
  sleep 2
done
```

### 4. Manual Promotion

Skip waiting periods and promote immediately:
```bash
kubectl argo rollouts promote hello-world-rollout -n thrive-app
```

### 5. Rollback Testing

Abort the deployment and return to the previous version:
```bash
kubectl argo rollouts abort hello-world-rollout -n thrive-app
kubectl argo rollouts undo hello-world-rollout -n thrive-app
```

## 📊 Monitoring Metrics

### Prometheus Queries

Open http://localhost:9090 and test these queries:

```promql
# Request rate by version
sum(rate(http_requests_total[5m])) by (version)

# Error rate comparison
sum(rate(http_requests_total{status_code!~"2.."}[5m])) by (version)

# Response time percentiles
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

### Grafana Dashboards

Login to http://localhost:3000 (admin/admin123) to view:
- Application performance metrics
- Infrastructure health monitoring
- Request/response analytics

## 🚨 Troubleshooting

### Check Rollout Status
```bash
kubectl describe rollout hello-world-rollout -n thrive-app
```

### View Argo Rollouts Controller Logs
```bash
kubectl logs -n argo-rollouts deployment/argo-rollouts-controller
```

### Verify ALB Controller
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## 🎯 Key Benefits Demonstrated

1. **Zero Downtime**: Application remains available throughout deployment
2. **Risk Mitigation**: Gradual traffic shift reduces blast radius
3. **Observability**: Real-time monitoring of deployment health
4. **Quick Recovery**: Fast rollback capability if issues arise
5. **Production Ready**: Enterprise-grade deployment strategy

---

This canary deployment setup provides production-ready, zero-downtime deployments with comprehensive monitoring and rollback capabilities.