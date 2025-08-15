# 🚀 Complete Deployment Guide - Fresh AWS Account

This guide provides **step-by-step instructions** to deploy the entire DevOps platform on a **brand new AWS account** from scratch.

## ⚡ **TL;DR - One Command Deployment**

```bash
# If you want to deploy everything quickly:
git clone https://github.com/Rajathbharadwaj/thrive-takehome.git
cd thrive-takehome
./scripts/setup.sh
```

> **Note**: The automated script includes all necessary fixes and optimizations to ensure a smooth deployment. It handles security group configurations, image builds, and networking automatically - no manual troubleshooting required!

## 📋 **Prerequisites Check**

Before starting, ensure you have:

1. ✅ **Fresh AWS Account** (free tier eligible)
2. ✅ **Valid email address** (for alerts)
3. ✅ **GitHub account** (for CI/CD)
4. ✅ **Local machine** with internet access

## 🛠️ **Step 1: Install Required Tools**

### **For macOS:**
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install awscli terraform kubectl docker
```

### **For Ubuntu/Debian:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Docker
sudo apt install docker.io -y
sudo usermod -aG docker $USER
```

### **For Windows (PowerShell):**
```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install tools
choco install awscli terraform kubernetes-cli docker-desktop -y
```

### **Verify Installations:**
```bash
aws --version        # Should show AWS CLI version
terraform --version  # Should show Terraform version
kubectl version --client  # Should show kubectl version
docker --version     # Should show Docker version
```

## 🔑 **Step 2: Setup AWS Account**

### **2.1 Create AWS Account**
1. Go to [aws.amazon.com](https://aws.amazon.com)
2. Click "Create an AWS Account"
3. Follow the registration process
4. **Important**: Choose the **Free Tier** to avoid unexpected charges

### **2.2 Create IAM User**
```bash
# Login to AWS Console
# Go to IAM → Users → Create User
# Name: terraform-user
# Attach policy: AdministratorAccess (for simplicity)
# Create user and download credentials
```

### **2.3 Configure AWS CLI**
```bash
aws configure
# AWS Access Key ID: [Enter your access key]
# AWS Secret Access Key: [Enter your secret key]  
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-user"
}
```

## 📥 **Step 3: Clone Repository**

```bash
# Clone the repository
git clone https://github.com/Rajathbharadwaj/thrive-takehome.git
cd thrive-takehome

# Verify repository contents
ls -la
```

**Expected files:**
```
├── README.md
├── Dockerfile
├── app/
├── terraform/
├── k8s/
├── .github/
├── monitoring/
└── scripts/
```

## ⚙️ **Step 4: Configure Deployment**

### **4.1 Setup Terraform Variables**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### **4.2 Edit Configuration**
```bash
# Edit terraform.tfvars with your details
nano terraform.tfvars  # or vim/code terraform.tfvars
```

**Required changes:**
```hcl
# Replace with your information
alert_email = "your-email@example.com"
github_repo = "your-username/your-repo-name"
aws_region  = "us-east-1"
environment = "production"
project_name = "thrive-takehome"

# Optional: Adjust instance sizes for cost
instance_types = ["t3.small"]  # Use t3.micro for lower cost
min_size = 1
max_size = 3
desired_size = 2
```

## 🏗️ **Step 5: Deploy Infrastructure**

### **5.1 Initialize Terraform**
```bash
terraform init
```

**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### **5.2 Plan Deployment**
```bash
terraform plan
```
Review the plan to ensure all resources look correct.

### **5.3 Deploy Infrastructure**
```bash
terraform apply
```

Type `yes` when prompted. **This takes 15-20 minutes**.

**Expected completion message:**
```
Apply complete! Resources: 45 added, 0 changed, 0 destroyed.

Outputs:
cluster_endpoint = "https://XXXXXXXXX.gr7.us-east-1.eks.amazonaws.com"
ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/thrive-hello-world"
```

## ☸️ **Step 6: Configure Kubernetes**

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name thrive-cluster

# Verify cluster access
kubectl get nodes
```

**Expected output:**
```
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-11-183.ec2.internal    Ready    <none>   5m    v1.28.3-eks-4f4795d
ip-10-0-12-11.ec2.internal     Ready    <none>   5m    v1.28.3-eks-4f4795d
```

## 🐳 **Step 7: Build and Deploy Application**

### **7.1 Get ECR Repository URL**
```bash
# Get your account ID and ECR URL
aws sts get-caller-identity --query Account --output text
aws ecr describe-repositories --repository-names thrive-hello-world --query 'repositories[0].repositoryUri' --output text
```

### **7.2 Build Docker Image**
```bash
# Return to project root
cd ..

# Build image
docker build -t thrive-hello-world .
```

### **7.3 Push to ECR**
```bash
# Login to ECR (replace ACCOUNT_ID)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag thrive-hello-world:latest ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/thrive-hello-world:latest

# Push image
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/thrive-hello-world:latest
```

### **7.4 Update Kubernetes Manifests**
```bash
# Update deployment with your ECR URL
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/866567874511/$ACCOUNT_ID/g" k8s/deployment.yaml
```

### **7.5 Deploy to Kubernetes**
```bash
# Deploy application
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for pods to be ready
kubectl get pods -n thrive-app -w
```

**Wait until you see:**
```
NAME                           READY   STATUS    RESTARTS   AGE
hello-world-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
hello-world-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

## 🌐 **Step 8: Access Your Application**

### **8.1 Get Load Balancer URL**
```bash
kubectl get ingress -n thrive-app
```

**Copy the ADDRESS field (ALB URL)**

### **8.2 Test Application**
```bash
# Replace with your ALB URL
export ALB_URL="your-alb-url.elb.amazonaws.com"

# Test main endpoint
curl http://$ALB_URL

# Test health check
curl http://$ALB_URL/health

# Test metrics
curl http://$ALB_URL/metrics
```

**Expected response:**
```json
{"message":"Hello World from Thrive! 🚀","timestamp":"2025-08-13T19:29:00.702Z","version":"1.0.0"}
```

## 🎛️ **Step 9: Verify Complete Deployment**

### **9.1 Check All Services**
```bash
# Check pods
kubectl get pods -n thrive-app

# Check services
kubectl get services -n thrive-app

# Check ingress
kubectl get ingress -n thrive-app

# Check HPA
kubectl get hpa -n thrive-app
```

### **9.2 Check AWS Resources**
```bash
# Check EKS cluster
aws eks describe-cluster --name thrive-cluster --query 'cluster.status'

# Check Load Balancer
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `thrive`)].State.Code'

# Check ECR repository
aws ecr describe-repositories --repository-names thrive-hello-world
```

### **9.3 Check Monitoring**
```bash
# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/thrive-cluster

# Check SNS alerts
aws sns list-topics --query 'Topics[?contains(TopicArn, `thrive`)]'
```

## 🔄 **Step 10: Setup CI/CD (Optional)**

### **10.1 Fork Repository**
1. Go to the repository on GitHub
2. Click "Fork" to create your own copy

### **10.2 Configure Secrets**
In your forked repository:
1. Go to Settings → Secrets and variables → Actions
2. Add these secrets:
   - `AWS_REGION`: `us-east-1`
   - `EKS_CLUSTER_NAME`: `thrive-cluster`
   - `ECR_REPOSITORY`: `thrive-hello-world`

### **10.3 Test CI/CD**
```bash
# Make a small change and push
echo "# Updated $(date)" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin main
```

Watch the Actions tab in GitHub for the pipeline execution.

## 📊 **Step 11: Access Monitoring**

### **11.1 Argo Rollouts Dashboard**
```bash
kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100
```
Visit: http://localhost:3100

### **11.2 Application Logs**
```bash
# Real-time logs
kubectl logs -f deployment/hello-world -n thrive-app

# CloudWatch logs
aws logs tail /aws/eks/thrive-cluster/application --follow
```

## 🧪 **Step 12: Test Advanced Features**

### **12.1 Test Auto-Scaling**
```bash
# Generate load to trigger scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside the pod:
while true; do wget -q -O- http://hello-world-service.thrive-app.svc.cluster.local; done

# In another terminal, watch scaling
kubectl get hpa -n thrive-app -w
```

### **12.2 Test Health Checks**
```bash
# Check if health endpoints work
curl http://$ALB_URL/health
curl http://$ALB_URL/ready
```

### **12.3 Test Canary Deployment**
```bash
# Deploy with Argo Rollouts
kubectl apply -f k8s/argo-rollouts.yaml

# Watch rollout progress
kubectl argo rollouts get rollout hello-world-rollout -n thrive-app --watch
```

## 🎯 **Success Criteria**

Your deployment is successful when:

✅ **Infrastructure**: EKS cluster with 2 nodes running  
✅ **Application**: 2 pods running in `thrive-app` namespace  
✅ **Load Balancer**: ALB accessible from internet  
✅ **Health Checks**: `/health` and `/ready` endpoints responding  
✅ **Metrics**: `/metrics` endpoint exposing Prometheus data  
✅ **Auto-scaling**: HPA configured and responsive  
✅ **Monitoring**: CloudWatch logs flowing  
✅ **Alerts**: SNS topic configured for email notifications  

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. Terraform fails with permissions error**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Ensure IAM user has AdministratorAccess policy
aws iam list-attached-user-policies --user-name terraform-user
```

#### **2. Pods not starting**
```bash
# Check pod status
kubectl describe pods -n thrive-app

# Check if image exists in ECR
aws ecr list-images --repository-name thrive-hello-world
```

#### **3. Load Balancer not accessible**
```bash
# Check ingress status
kubectl describe ingress -n thrive-app

# Check target group health
aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName, `thrive`)]'
```

#### **4. High AWS costs**
```bash
# Check billing
aws ce get-cost-and-usage --time-period Start=2025-01-01,End=2025-01-31 --granularity MONTHLY --metrics BlendedCost

# Stop cluster temporarily
kubectl scale deployment hello-world --replicas=0 -n thrive-app
```

### **Support Commands**
```bash
# View all resources
kubectl get all -A
terraform state list
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'

# Debug networking
kubectl exec -it deployment/hello-world -n thrive-app -- /bin/sh
nslookup kubernetes.default.svc.cluster.local
```

## 🛡️ **What We Fixed for You**

The automated deployment script includes several optimizations to prevent common issues:

### **Security Group Conflicts**
- **Issue**: Multiple security groups with cluster tags can confuse the Load Balancer Controller
- **Fix**: Script automatically removes conflicting tags and adds proper ingress rules
- **Result**: ALB communicates with pods immediately without manual intervention

### **Image Registry Issues**
- **Issue**: Deployment might reference wrong ECR account ID
- **Fix**: Script automatically detects your account ID and updates all references
- **Result**: Pods pull the correct image from your ECR repository

### **Load Balancer Timing**
- **Issue**: ALB might take time to provision and register targets
- **Fix**: Script waits for proper readiness and validates connectivity
- **Result**: Application is accessible immediately after deployment completes

### **Health Check Configuration**
- **Issue**: Default health check paths might not match application endpoints
- **Fix**: Pre-configured to use `/health` endpoint with proper intervals
- **Result**: Targets register as healthy quickly and reliably

**Bottom Line**: The deployment should work smoothly on any fresh AWS account without the manual troubleshooting steps we went through during development! 🚀

## 💰 **Cost Management**

### **Daily Costs (Approximate)**
- EKS Cluster: $2.40/day
- EC2 Instances: $1.00/day  
- Load Balancer: $0.53/day
- Other: $0.30/day
- **Total**: ~$4.23/day

### **Cost Optimization**
```bash
# Use smaller instances
sed -i 's/t3.small/t3.micro/g' terraform/main.tf

# Scale down for testing
kubectl scale deployment hello-world --replicas=1 -n thrive-app

# Stop when not needed
terraform destroy -auto-approve
```

## 🧹 **Cleanup**

### **Complete Cleanup**
```bash
# Delete Kubernetes resources
kubectl delete namespace thrive-app
kubectl delete namespace argo-rollouts

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

### **Verify Cleanup**
```bash
# Check no EKS clusters
aws eks list-clusters

# Check no load balancers
aws elbv2 describe-load-balancers

# Check billing (after a few hours)
aws ce get-cost-and-usage --time-period Start=2025-01-01,End=2025-01-31 --granularity DAILY --metrics BlendedCost
```

---

## ✅ **Final Checklist**

Before considering deployment complete:

- [ ] AWS account configured and verified
- [ ] All tools installed and working
- [ ] Repository cloned and configured
- [ ] Terraform applied successfully
- [ ] EKS cluster accessible via kubectl
- [ ] Docker image built and pushed to ECR
- [ ] Application deployed and running
- [ ] Load balancer accessible from internet
- [ ] Health checks responding
- [ ] Monitoring configured
- [ ] CI/CD pipeline setup (optional)
- [ ] Costs monitored and understood

**🎉 Congratulations! You have successfully deployed a production-ready DevOps platform on AWS!**

