terraform {
  required_version = ">= 1.5"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

provider "restapi" {
  uri                  = var.loki_url
  write_returns_object = true
  id_attribute         = "id"

  headers = {
    Authorization = "Basic ${base64encode("${var.loki_tenant}:${var.loki_token}")}"
    Content-Type  = "application/json"
  }
}

# module "billing_segment" {
#   source = "../../modules/segment"
#
#   name     = "Billing API"
#   selector = "{service_name=\"billing-api\"}"
# }

module "drop_debug_api_gateway" {
  source = "../../modules/drop-rule"

  name            = "Drop debug logs on api-gateway"
  stream_selector = "{service_name=\"api-gateway\"}"
  drop_rate       = 100
  levels          = ["debug"]
}

# module "exempt_api_gateway_prod" {
#   source = "../../modules/exemption"

#   stream_selector = "{service_name=\"api-gateway\", env=\"prod\"}"
#   reason          = "Investigating latency spike — keep full fidelity"
#   expires_at      = "2026-06-01T00:00:00Z"
# }
