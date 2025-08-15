# cert-manager for HTTPS/TLS automation
# This file enables automatic SSL certificate management

# Install cert-manager using Helm
resource "helm_release" "cert_manager" {
  count = var.enable_https ? 1 : 0
  
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.13.0"
  namespace  = "cert-manager"
  
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }
  
  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }
  
  # Enable IRSA for cert-manager
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager[0].arn
  }
  
  depends_on = [
    module.eks,
    aws_iam_role.cert_manager
  ]
}

# IAM Role for cert-manager (IRSA)
resource "aws_iam_role" "cert_manager" {
  count = var.enable_https ? 1 : 0
  
  name = "${var.project_name}-cert-manager-role"
  
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
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:cert-manager:cert-manager"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# IAM Policy for cert-manager Route53 access
resource "aws_iam_role_policy" "cert_manager_route53" {
  count = var.enable_https ? 1 : 0
  
  name = "${var.project_name}-cert-manager-route53"
  role = aws_iam_role.cert_manager[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}

# ClusterIssuer for Let's Encrypt (if domain is provided)
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count = var.enable_https && var.domain_name != "" ? 1 : 0
  
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.alert_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = var.aws_region
              }
            }
          }
        ]
      }
    }
  }
  
  depends_on = [helm_release.cert_manager]
}

# Certificate resource (if domain is provided)
resource "kubernetes_manifest" "app_certificate" {
  count = var.enable_https && var.domain_name != "" ? 1 : 0
  
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "app-tls"
      namespace = "thrive-app"
    }
    spec = {
      secretName = "app-tls-secret"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.domain_name
      ]
    }
  }
  
  depends_on = [kubernetes_manifest.letsencrypt_issuer]
}

# Route53 Hosted Zone (if domain is provided)
resource "aws_route53_zone" "main" {
  count = var.enable_https && var.domain_name != "" ? 1 : 0
  
  name = var.domain_name
  
  tags = merge(local.common_tags, {
    Name = var.domain_name
  })
}

# Output the name servers for domain configuration
output "route53_name_servers" {
  description = "Route53 name servers for domain configuration"
  value = var.enable_https && var.domain_name != "" ? aws_route53_zone.main[0].name_servers : []
}

output "certificate_arn" {
  description = "ARN of the SSL certificate (for manual ACM setup)"
  value = var.enable_https ? "Configure ACM certificate manually or use cert-manager" : "HTTPS not enabled"
}
