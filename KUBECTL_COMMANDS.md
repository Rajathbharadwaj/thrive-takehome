# 🚀 Kubectl Commands Reference

Essential kubectl commands to monitor and manage your Thrive DevOps platform.

## 📊 **Quick Status Overview**

### **All Resources at a Glance**
```bash
# Get everything in all namespaces
kubectl get all -A

# Quick status of your application
kubectl get pods,svc,ingress -n thrive-app

# Check rollout status
kubectl get rollouts -n thrive-app
```

## 🔍 **Pod Management & Monitoring**

### **Check Pod Status**
```bash
# List all pods in thrive-app namespace
kubectl get pods -n thrive-app

# List all pods with more details
kubectl get pods -n thrive-app -o wide

# Watch pods in real-time (press Ctrl+C to stop)
kubectl get pods -n thrive-app -w

# Count total pods running
kubectl get pods -A --field-selector=status.phase=Running | wc -l
```

### **Pod Details & Troubleshooting**
```bash
# Describe a specific pod (replace POD_NAME)
kubectl describe pod POD_NAME -n thrive-app

# Get pod logs (replace POD_NAME)
kubectl logs POD_NAME -n thrive-app

# Follow logs in real-time
kubectl logs -f POD_NAME -n thrive-app

# Get logs from all pods with label app=hello-world
kubectl logs -l app=hello-world -n thrive-app
```

### **Resource Usage**
```bash
# Check resource usage (requires metrics server)
kubectl top pods -n thrive-app

# Check node resource usage
kubectl top nodes
```

## 🎯 **Argo Rollouts (Canary Deployments)**

### **Rollout Status**
```bash
# Check rollout status
kubectl get rollouts -n thrive-app

# Detailed rollout information
kubectl describe rollout hello-world-rollout -n thrive-app

# Watch rollout progress
kubectl get rollouts -n thrive-app -w
```

### **Rollout Management**
```bash
# Trigger a new rollout (change image)
kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
  -p='{"spec":{"template":{"spec":{"containers":[{"name":"hello-world","image":"nginx:latest"}]}}}}'

# Promote rollout to 100%
kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
  -p='{"metadata":{"annotations":{"rollouts.argoproj.io/promote":"true"}}}'

# Abort/rollback current rollout
kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' \
  -p='{"metadata":{"annotations":{"rollouts.argoproj.io/abort":"true"}}}'
```

## 🌐 **Services & Networking**

### **Service Information**
```bash
# List all services
kubectl get svc -n thrive-app

# Describe service details
kubectl describe svc hello-world-service -n thrive-app

# Check service endpoints
kubectl get endpoints -n thrive-app
```

### **Ingress & Load Balancer**
```bash
# Check ingress status
kubectl get ingress -n thrive-app

# Get ALB URL
kubectl get ingress hello-world-ingress -n thrive-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Describe ingress for troubleshooting
kubectl describe ingress hello-world-ingress -n thrive-app
```

### **Port Forwarding (for local access)**
```bash
# Forward pod port to local machine
kubectl port-forward pod/POD_NAME -n thrive-app 8080:3000

# Forward service port to local machine
kubectl port-forward svc/hello-world-service -n thrive-app 8080:80
```

## 📊 **Monitoring Stack**

### **Monitoring Pods**
```bash
# Check monitoring namespace
kubectl get pods -n monitoring

# Check Argo Rollouts namespace
kubectl get pods -n argo-rollouts

# All monitoring services
kubectl get svc -n monitoring
kubectl get svc -n argo-rollouts
```

### **Dashboard Access**
```bash
# Start Argo Rollouts dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100

# Start Prometheus
kubectl port-forward svc/prometheus-service -n monitoring 9090:9090

# Start Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000
```

## 🔧 **Cluster Information**

### **Cluster Status**
```bash
# Check cluster info
kubectl cluster-info

# List all nodes
kubectl get nodes

# Describe node details
kubectl describe nodes

# Check node capacity and usage
kubectl describe nodes | grep -A 5 "Capacity\|Allocatable"
```

### **Namespace Management**
```bash
# List all namespaces
kubectl get namespaces

# Check resources in specific namespace
kubectl get all -n thrive-app
kubectl get all -n monitoring
kubectl get all -n argo-rollouts
```

## 🚨 **Troubleshooting Commands**

### **Common Issues**
```bash
# Check for failing pods
kubectl get pods -A | grep -v Running

# Get events for troubleshooting
kubectl get events -n thrive-app --sort-by='.lastTimestamp'

# Check pod restart counts
kubectl get pods -n thrive-app -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount

# Describe problem pods
kubectl describe pod POD_NAME -n thrive-app | tail -20
```

### **Resource Validation**
```bash
# Validate YAML files before applying
kubectl apply --dry-run=client -f k8s/deployment.yaml

# Check what would be deleted
kubectl delete --dry-run=client -f k8s/deployment.yaml
```

## 🎯 **Application Testing**

### **Health Checks**
```bash
# Test application endpoints through kubectl
kubectl run test-pod --image=curlimages/curl -it --rm -- /bin/sh

# Inside the test pod:
curl hello-world-service.thrive-app.svc.cluster.local/health
curl hello-world-service.thrive-app.svc.cluster.local/metrics
```

### **Load Testing**
```bash
# Simple load test using kubectl
kubectl run load-test --image=busybox -it --rm -- /bin/sh

# Inside the load test pod:
while true; do wget -q -O- hello-world-service.thrive-app.svc.cluster.local; sleep 1; done
```

## 📝 **Configuration Management**

### **ConfigMaps & Secrets**
```bash
# List configmaps and secrets
kubectl get configmaps -n thrive-app
kubectl get secrets -n thrive-app

# Describe secret (without showing values)
kubectl describe secret SECRET_NAME -n thrive-app
```

### **Apply/Update Resources**
```bash
# Apply single file
kubectl apply -f k8s/deployment.yaml

# Apply entire directory
kubectl apply -f k8s/

# Update specific resource
kubectl patch deployment hello-world -n thrive-app -p '{"spec":{"replicas":3}}'
```

## 🔄 **Scaling Operations**

### **Manual Scaling**
```bash
# Scale deployment
kubectl scale deployment hello-world -n thrive-app --replicas=3

# Scale rollout
kubectl patch rollout hello-world-rollout -n thrive-app --type='merge' -p='{"spec":{"replicas":3}}'
```

### **Horizontal Pod Autoscaler (HPA)**
```bash
# Check HPA status
kubectl get hpa -n thrive-app

# Describe HPA
kubectl describe hpa hello-world-hpa -n thrive-app
```

## 🚀 **Quick Reference Summary**

| **Command** | **Description** |
|-------------|-----------------|
| `kubectl get pods -n thrive-app` | List application pods |
| `kubectl get rollouts -n thrive-app` | Check canary deployment status |
| `kubectl logs -f POD_NAME -n thrive-app` | Follow pod logs |
| `kubectl describe pod POD_NAME -n thrive-app` | Debug pod issues |
| `kubectl get ingress -n thrive-app` | Get application URL |
| `kubectl get all -A` | Overview of entire cluster |
| `kubectl cluster-info` | Basic cluster information |
| `kubectl get events -n thrive-app` | Recent events for troubleshooting |

## 💡 **Pro Tips**

### **Aliases for Faster Commands**
```bash
# Add these to your ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgi='kubectl get ingress'
alias kdp='kubectl describe pod'
alias klf='kubectl logs -f'

# Usage examples:
k get pods -n thrive-app
kgp -n thrive-app
klf POD_NAME -n thrive-app
```

### **Useful One-Liners**
```bash
# Get pod IPs
kubectl get pods -n thrive-app -o wide | awk 'NR>1{print $1, $6}'

# Count pods by status
kubectl get pods -A | tail -n +2 | awk '{print $4}' | sort | uniq -c

# Get all pod resource requests
kubectl get pods -n thrive-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.spec.containers[0].resources.requests.memory}{"\n"}{end}'
```

---

## 🎯 **For Your Take-Home Demo**

**Essential commands to show during interviews:**
```bash
# Show application is running
kubectl get pods,svc,ingress -n thrive-app

# Show canary deployment capability
kubectl get rollouts -n thrive-app

# Show monitoring stack
kubectl get pods -n monitoring -n argo-rollouts

# Show cluster health
kubectl get nodes
kubectl cluster-info
```

This demonstrates your complete DevOps platform with production-grade monitoring and deployment automation! 🚀
