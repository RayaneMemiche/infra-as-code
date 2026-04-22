# Monitoring Module - Outputs

output "namespace" {
  description = "Monitoring namespace name"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.kube_prometheus_stack.name
}

output "prometheus_service" {
  description = "Prometheus service name for internal access"
  value       = "${helm_release.kube_prometheus_stack.name}-prometheus"
}

output "grafana_service" {
  description = "Grafana service name for internal access"
  value       = "${helm_release.kube_prometheus_stack.name}-grafana"
}

output "alertmanager_service" {
  description = "Alertmanager service name for internal access"
  value       = "${helm_release.kube_prometheus_stack.name}-alertmanager"
}

output "grafana_port_forward_command" {
  description = "Command to port-forward Grafana for local access"
  value       = "kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/${helm_release.kube_prometheus_stack.name}-grafana 3000:80"
}

output "prometheus_port_forward_command" {
  description = "Command to port-forward Prometheus for local access"
  value       = "kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/${helm_release.kube_prometheus_stack.name}-prometheus 9090:9090"
}
