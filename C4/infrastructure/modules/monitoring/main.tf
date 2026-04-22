# Monitoring Stack Module
# Deploys kube-prometheus-stack via Helm for Prometheus, Grafana, Alertmanager

# ============================================================================
# NAMESPACE
# ============================================================================

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace

    labels = merge(var.labels, {
      "app.kubernetes.io/managed-by" = "terraform"
      "purpose"                      = "monitoring"
    })
  }
}

# ============================================================================
# KUBE-PROMETHEUS-STACK HELM RELEASE
# ============================================================================

resource "helm_release" "kube_prometheus_stack" {
  name       = "c4-monitoring-${var.environment}"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version

  # Timeout for large chart
  timeout = 600

  # Wait for all resources to be ready
  wait = true

  # Base values file + environment-specific overrides
  values = [
    file("${path.module}/../../helm/monitoring/values.yaml"),
    file("${path.module}/../../helm/monitoring/values-${var.environment}.yaml"),
  ]

  # Dynamic overrides via Terraform variables
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.prometheus_retention
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.alertmanager_storage_size
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ============================================================================
# CUSTOM GRAFANA DASHBOARD - Task Manager API
# ============================================================================

resource "kubernetes_config_map" "grafana_dashboard_taskmanager" {
  metadata {
    name      = "grafana-dashboard-task-manager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "task-manager-api.json" = file("${path.module}/../../helm/monitoring/dashboards/task-manager-api.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
