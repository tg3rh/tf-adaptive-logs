variable "loki_url" {
  description = "Loki base URL, e.g. https://logs-prod-us-central1.grafana.net"
  type        = string
}

variable "loki_tenant" {
  description = "Numeric instance ID from your Loki endpoint details."
  type        = string
}

variable "loki_token" {
  description = "Grafana Cloud Access Policy token with the adaptive-logs:admin scope."
  type        = string
  sensitive   = true
}
