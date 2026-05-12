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

module "adaptive_logs" {
  source = "../.."

  segments = {
    billing = {
      name     = "Billing API"
      selector = "{service_name=\"billing-api\"}"
    }
  }

  drop_rules = {
    debug-api-gateway = {
      name            = "Drop debug logs on api-gateway"
      stream_selector = "{service_name=\"api-gateway\"}"
      drop_rate       = 100
      levels          = ["debug"]
    }

    debug-billing = {
      segment         = "billing"
      name            = "Drop debug logs on billing-api"
      stream_selector = "{service_name=\"billing-api\"}"
      drop_rate       = 100
      levels          = ["debug"]
    }
  }

  exemptions = {
    api-gateway-prod = {
      stream_selector = "{service_name=\"api-gateway\", env=\"prod\"}"
      reason          = "Investigating latency spike - keep full fidelity"
    }
  }
}
