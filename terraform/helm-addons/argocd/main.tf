# Create a Random Passworn for ArgoCD
resource "random_string" "argo_password" {
  length = 16
  special = true
  min_upper = 3
  min_lower = 3
  min_numeric = 3
  min_special = 3
  override_special = "!@#%&+/"
}

# Create ArgoCD Namespace
resource "kubernetes_namespace" "argocd_namespace" {
  metadata {
    name = "argocd"
  }
}

# Create Github Authentication Secrets for Argo 
resource "kubernetes_secret" "github_auth" {
  metadata {
    name = "github-auth"
    namespace = "argocd"
  }

  data = {
    "username" = var.github_username
    "password" = var.github_password
  }
}

# Helm Installation of ArgoCD Chart
resource "helm_release" "argocd" {
  name = "argocd"
  chart = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version = "7.7.3"
  namespace = "argocd"
  values = [
    templatefile("${path.module}/files/values.yaml", {
        github_username = kubernetes_secret.github_auth.data.username
        github_password = kubernetes_secret.github_auth.data.password
        argocdServerAdminPassword = bcrypt(random_string.argo_password.result)
        argocdServerAdminPasswordMtime = timestamp()
    })
  ]
}