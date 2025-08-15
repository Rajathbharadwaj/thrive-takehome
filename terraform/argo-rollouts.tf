# Argo Rollouts for Blue-Green and Canary Deployments
# This enables advanced deployment strategies

# Install Argo Rollouts using Helm
resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = "2.32.0"
  namespace  = "argo-rollouts"
  
  create_namespace = true
  
  # Clean up CRDs on destroy
  set {
    name  = "keepCRDs"
    value = "false"
  }
  
  set {
    name  = "dashboard.enabled"
    value = "true"
  }
  
  set {
    name  = "dashboard.service.type"
    value = "ClusterIP"
  }
  
  # Enable notifications
  set {
    name  = "notifications.enabled"
    value = "true"
  }
  
  wait    = true
  timeout = 600
  
  depends_on = [
    module.eks,
    helm_release.aws_load_balancer_controller,
    time_sleep.wait_for_load_balancer_controller
  ]
}

# Service Account for Argo Rollouts (IRSA)
resource "aws_iam_role" "argo_rollouts" {
  name = "${var.project_name}-argo-rollouts-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:argo-rollouts:argo-rollouts"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM Policy for Argo Rollouts ALB integration
resource "aws_iam_role_policy" "argo_rollouts_alb" {
  name = "${var.project_name}-argo-rollouts-alb"
  role = aws_iam_role.argo_rollouts.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

# Note: Service Account is created by Helm chart
# We'll patch it manually to add IRSA annotation

# RBAC for Argo Rollouts to access ALB resources
resource "kubernetes_cluster_role" "argo_rollouts_alb" {
  metadata {
    name = "argo-rollouts-alb"
  }
  
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }
  
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }
  
  rule {
    api_groups = ["argoproj.io"]
    resources  = ["rollouts", "rollouts/status"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }
}

# Note: Cluster role binding can be added manually if needed
# kubectl create clusterrolebinding argo-rollouts-alb --clusterrole=argo-rollouts-alb --serviceaccount=argo-rollouts:argo-rollouts

# Note: Dashboard service is created by Helm chart

# Note: We'll access the dashboard via kubectl port-forward for now
# ALB ingress can be added later if needed

# Output Argo Rollouts information
output "argo_rollouts_namespace" {
  description = "Namespace where Argo Rollouts is installed"
  value       = helm_release.argo_rollouts.namespace
}

output "argo_rollouts_dashboard_url" {
  description = "URL to access Argo Rollouts dashboard"
  value = "Access via: kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100"
}
