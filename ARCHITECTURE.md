# Architecture Document

## 🏗️ System Overview

This solution implements a production-ready, scalable web application on AWS using modern DevOps practices. The architecture follows cloud-native principles with emphasis on observability, security, and cost optimization.

## 🎯 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Internet                                   │
└──────────────────────────────┬──────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud                                    │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        VPC (10.0.0.0/16)                       │   │
│  │                                                                 │   │
│  │  ┌──────────────────┐     ┌──────────────────────────────────┐ │   │
│  │  │  Public Subnets  │     │         Private Subnets          │ │   │
│  │  │                  │     │                                  │ │   │
│  │  │  ┌─────────────┐ │     │ ┌─────────────────────────────┐  │ │   │
│  │  │  │     ALB     │◄┼─────┼─┤        EKS Cluster          │  │ │   │
│  │  │  └─────────────┘ │     │ │                             │  │ │   │
│  │  │                  │     │ │  ┌───────┐    ┌───────┐     │  │ │   │
│  │  │  ┌─────────────┐ │     │ │  │ Pod 1 │    │ Pod 2 │     │  │ │   │
│  │  │  │ NAT Gateway │◄┼─────┼─┤  └───────┘    └───────┘     │  │ │   │
│  │  │  └─────────────┘ │     │ │                             │  │ │   │
│  │  └──────────────────┘     │ │  ┌───────────────────────┐   │  │ │   │
│  │                           │ │  │   Monitoring Stack    │   │  │ │   │
│  │                           │ │  │ Prometheus + Grafana  │   │  │ │   │
│  │                           │ │  └───────────────────────┘   │  │ │   │
│  │                           │ └─────────────────────────────┘  │ │   │
│  │                           └──────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │     ECR     │  │   Secrets   │  │ CloudWatch  │  │     SNS     │    │
│  │ Container   │  │  Manager    │  │   Metrics   │  │   Alerts    │    │
│  │  Registry   │  │             │  │  & Logs     │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                          CI/CD Pipeline                                │
│                                                                         │
│  Developer ──push──► GitHub ──webhook──► GitHub Actions ──deploy──► EKS │
│      │                                         │                       │
│      └─────────────── build/push ─────────────►ECR                     │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🔧 Component Details

### Infrastructure Layer

#### VPC (Virtual Private Cloud)
- **Type**: AWS Default VPC (cost optimization)
- **CIDR**: 172.31.0.0/16 (default VPC)
- **Subnets**: Default public subnets across multiple AZs
- **Internet Gateway**: Default VPC Internet Gateway
- **Cost Benefit**: No additional VPC/subnet charges, simplified networking

#### EKS (Elastic Kubernetes Service)
- **Cluster Name**: thrive-prod-cluster-fresh
- **Version**: 1.31 (latest stable)
- **Node Group**: 2 t3.small instances (cost-optimized)
- **Auto Scaling**: Enabled with HPA (2-10 pods)
- **IRSA**: IAM Roles for Service Accounts configured
- **Add-ons**: AWS Load Balancer Controller, EBS CSI Driver
- **Networking**: Uses default VPC subnets (EKS-compatible AZs only)

#### Application Load Balancer (ALB)
- **Type**: Internet-facing
- **Health Checks**: /health endpoint
- **Target Type**: IP (for EKS integration)
- **SSL/TLS**: Ready for cert-manager integration

### Application Layer

#### Hello World Node.js App
```javascript
Features:
- Express.js web server
- Prometheus metrics endpoint (/metrics)
- Health check endpoints (/health, /ready)
- Environment-aware configuration
- Graceful shutdown handling
- Security best practices (non-root user)
```

#### Container Configuration
```dockerfile
Base Image: node:18-alpine
Multi-stage build: Yes
Security: Non-root user, distroless runtime
Health checks: Built-in Docker health check
Size optimization: Alpine base, npm ci --only=production
```

#### Kubernetes Manifests
- **Deployment**: 2 replicas with resource limits
- **Service**: ClusterIP with load balancing
- **HPA**: CPU/Memory based auto-scaling (2-10 pods)
- **Ingress**: ALB integration with health checks

### Monitoring & Observability

#### Prometheus Stack
```yaml
Components:
  - Prometheus server (metrics collection)
  - Grafana (visualization)
  - Custom dashboards (application metrics)
  
Metrics Collected:
  - Application: HTTP requests, response times, errors
  - Infrastructure: CPU, memory, network, disk
  - Kubernetes: Pod status, resource usage
```

#### CloudWatch Integration
- **Logs**: Application and system logs
- **Metrics**: Custom application metrics
- **Alarms**: CPU threshold alerts
- **SNS**: Email notifications

#### Application Metrics
```javascript
Custom Metrics:
- http_requests_total (counter)
- http_request_duration_seconds (histogram)
- Node.js default metrics (memory, GC, etc.)
```

### Security Architecture

#### Network Security
```yaml
Security Groups:
  - ALB: Allow 80/443 from internet
  - EKS Nodes: Allow ALB traffic + inter-node communication
  - Control Plane: Managed by AWS

Network Isolation:
  - Private subnets for workloads
  - Public subnets only for load balancers
  - NAT Gateway for outbound traffic
```

#### Identity & Access Management
```yaml
IAM Roles:
  - EKS Cluster Role: Manage cluster
  - Node Group Role: EC2 and ECR access
  - IRSA Roles: Service-specific permissions
  - GitHub Actions Role: OIDC-based deployment

Security Features:
  - IRSA for pod-level permissions
  - Secrets Manager for sensitive data
  - ECR image scanning
  - Non-root containers
```

#### Container Security
```yaml
Security Measures:
  - Multi-stage builds
  - Minimal base images (Alpine)
  - Non-root user execution
  - Read-only root filesystem
  - Security context policies
  - Image vulnerability scanning
```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
Trigger: Push to main branch (app/infrastructure code only)
Path Filters: Excludes README.md and documentation changes
Stages:
  1. Build:
     - Checkout code
     - Build Docker image
     - Push to ECR
  
  2. Deploy:
     - Configure AWS credentials (OIDC)
     - Verify EKS cluster exists
     - Configure kubectl access
     - Apply manifests if deployment missing (self-healing)
     - Update application image
     - Verify deployment health

Authentication: OIDC (no long-lived credentials)
Smart Deployment: Auto-applies manifests for missing deployments
```

### Deployment Strategy
- **Rolling Updates**: Zero-downtime deployments
- **Health Checks**: Readiness/Liveness probes
- **Auto Rollback**: On failed health checks
- **Blue-Green Ready**: Argo Rollouts integration available

## 💰 Cost Analysis

### Monthly Cost Breakdown (Estimated)
```yaml
Core Infrastructure:
  - EKS Control Plane: $72 ($0.10/hour)
  - 2x t3.small nodes: $42 ($0.0208/hour each)
  - ALB: $16.20 ($0.0225/hour)
  - Default VPC: $0 (no additional charges)
  - ECR: $1-2 (image storage)
  - Data Transfer: $5-10 (15GB free tier)
  
Total Estimated: $135-142/month
Cost Savings: ~$32/month vs custom VPC with NAT Gateway
```

### Cost Optimization Strategies
1. **Default VPC Usage**: Saves ~$32/month vs custom VPC + NAT (implemented)
2. **t3.micro nodes**: Could save ~$21/month (free tier eligible)
3. **Spot Instances**: 50-70% savings on compute
4. **Scheduled Scaling**: Scale down during off-hours
5. **Reserved Instances**: 30-50% savings for predictable workloads
6. **ECR Lifecycle Policies**: Automatic cleanup of old images (implemented)

### Free Tier Considerations
```yaml
Eligible Services:
  - EC2: 750 hours/month t3.micro (can run 1 node free)
  - EBS: 30GB free
  - CloudWatch: 5GB logs, 10 metrics free
  - ECR: 500MB free
  - Data Transfer: 15GB/month free

Non-Free Tier:
  - EKS Control Plane: $72/month
  - ALB: $16.20/month
  - Default VPC: $0/month (major cost savings)
```

## 🔄 Scalability Design

### Horizontal Scaling
```yaml
Application Tier:
  - HPA: 2-10 pods based on CPU/memory
  - Custom metrics: Can scale on request rate
  - Multi-AZ deployment for HA

Infrastructure Tier:
  - Cluster Autoscaler: 1-3 nodes
  - Multi-AZ node groups
  - Load balancer automatically distributes traffic
```

### Vertical Scaling
```yaml
Resource Management:
  - Resource requests/limits defined
  - VPA available for automatic sizing
  - Node instance types easily changeable
```

### Data Scaling
```yaml
Storage:
  - EBS volumes with auto-expansion
  - EFS for shared storage (if needed)
  - S3 for static assets/logs

Database (Future):
  - RDS with read replicas
  - ElastiCache for caching
  - DynamoDB for NoSQL needs
```

## 🛡️ High Availability & Disaster Recovery

### High Availability
```yaml
Multi-AZ Deployment:
  - Spans 3 availability zones
  - Load balancer health checks
  - Auto-healing with pod restarts
  - Node replacement on failure

Application Level:
  - Multiple replicas (2 minimum)
  - Rolling updates
  - Circuit breaker patterns (future)
  - Graceful shutdown handling
```

### Disaster Recovery
```yaml
Backup Strategy:
  - Infrastructure as Code (Terraform)
  - Container images in ECR
  - Configuration in Git
  - Automated deployment pipeline

Recovery Procedures:
  - RTO: 15-30 minutes (new region deployment)
  - RPO: Near-zero (stateless application)
  - Automated failover (future with Route 53)
```

## 🔍 Monitoring Strategy

### Three Pillars of Observability

#### 1. Metrics (Prometheus + CloudWatch)
```yaml
Application Metrics:
  - Request rate, latency, errors (RED)
  - Business metrics (user signups, etc.)
  
Infrastructure Metrics:
  - CPU, memory, network, disk (USE)
  - Kubernetes cluster metrics
  
Alerting:
  - SLA/SLO based alerts
  - Anomaly detection
```

#### 2. Logs (CloudWatch Logs)
```yaml
Log Types:
  - Application logs (structured JSON)
  - Access logs (ALB)
  - Kubernetes events
  - Audit logs

Log Aggregation:
  - Centralized in CloudWatch
  - Searchable and filterable
  - Retention policies applied
```

#### 3. Traces (Future: AWS X-Ray)
```yaml
Distributed Tracing:
  - Request flow tracking
  - Performance bottlenecks
  - Error propagation
```

### Dashboards & Alerting
```yaml
Grafana Dashboards:
  - Application performance
  - Infrastructure health
  - Business metrics
  - SLA/SLO tracking

Alert Channels:
  - Email notifications (SNS)
  - Slack integration (future)
  - PagerDuty for critical alerts (future)
```

## 🚦 Performance Characteristics

### Expected Performance
```yaml
Response Times:
  - P50: < 50ms
  - P95: < 200ms
  - P99: < 500ms

Throughput:
  - 1000+ requests/second per pod
  - Auto-scaling triggers at 70% CPU

Availability:
  - Target: 99.9% uptime
  - Maximum downtime: 8.77 hours/year
```

### Load Testing Strategy
```yaml
Tools: k6, Artillery, or curl-based scripts
Scenarios:
  - Normal load: 100 RPS
  - Peak load: 500 RPS
  - Stress test: 1000+ RPS
  
Metrics to Monitor:
  - Response times
  - Error rates
  - Resource utilization
  - Auto-scaling behavior
```

## 🔮 Future Enhancements

### Phase 2 Improvements
```yaml
Application:
  - Database integration (RDS/DynamoDB)
  - Redis caching layer
  - User authentication
  - API rate limiting

Infrastructure:
  - Multi-region deployment
  - Blue-green deployments (Argo Rollouts)
  - Service mesh (Istio)
  - GitOps with ArgoCD

Security:
  - WAF (Web Application Firewall)
  - Network policies
  - Pod security policies
  - Vulnerability scanning

Monitoring:
  - Distributed tracing (X-Ray)
  - Custom business metrics
  - AI-powered anomaly detection
  - Cost monitoring dashboards
```

### Scalability Roadmap
```yaml
10x Scale Targets:
  - 10,000+ RPS capability
  - Multi-region active-active
  - Auto-scaling to 100+ pods
  - Database read replicas
  - CDN integration (CloudFront)
```

## 📝 Decision Log

### Key Architecture Decisions

#### 1. EKS vs. ECS
**Decision**: EKS  
**Rationale**: Better ecosystem for monitoring tools (Prometheus, Grafana), more flexible, industry standard for container orchestration

#### 2. ALB vs. NLB
**Decision**: ALB  
**Rationale**: Better health checks, path-based routing, integration with WAF, HTTP/2 support

#### 3. Custom VPC vs. Default VPC
**Decision**: Default VPC  
**Rationale**: Cost optimization (~$32/month savings), simplified networking, no NAT Gateway charges

#### 4. Prometheus vs. CloudWatch Only
**Decision**: Both  
**Rationale**: Prometheus for application metrics and alerting, CloudWatch for AWS service integration

#### 5. Rolling vs. Blue-Green Deployments
**Decision**: Rolling (with Blue-Green ready)  
**Rationale**: Simpler setup, adequate for MVP, Blue-Green available via Argo Rollouts

### Trade-offs Made

#### Cost vs. Features
- Default VPC: Simplified networking for significant cost savings
- t3.small nodes: Balance between cost and performance
- ALB: Increased cost but better features vs NLB

#### Complexity vs. Observability
- Added monitoring stack: Increased complexity but crucial for production
- Multiple metrics systems: Redundancy but comprehensive coverage

#### Security vs. Accessibility
- Default VPC public subnets: Simplified access but requires security groups for protection
- IRSA: More complex setup but better security than static credentials

## 🔗 External Dependencies

### AWS Services
- EC2, Default VPC, EKS, ECR, ALB
- CloudWatch, SNS, Secrets Manager, IAM, KMS
- Route 53 (future), ACM (future), WAF (future)

### Third-party Services
- GitHub (code repository and CI/CD)
- Docker Hub (base images)
- Prometheus/Grafana (monitoring)

### Open Source Components
- Kubernetes, Docker, Terraform
- AWS Load Balancer Controller
- cert-manager (future), Argo Rollouts (future)

---

This architecture provides a solid foundation for a production-ready application with room for growth and enhancement based on evolving requirements.
