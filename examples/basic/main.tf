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
      name     = "Frontend-Service"
      selector = "{service_name=\"frontend-service\"}"
    }
  }

  drop_rules = {
    debug-api-gateway = {
      name            = "Drop debug logs on orders"
      stream_selector = "{service_name=\"orders\"}"
      drop_rate       = 100
      levels          = ["debug"]
    }

    debug-billing = {
      segment         = "billing"
      name            = "Drop debug logs on customers"
      stream_selector = "{service_name=\"customers\"}"
      drop_rate       = 100
      levels          = ["debug"]
    }
  }

  exemptions = {
    frontend-service-prod = {
      stream_selector = "{service_name=\"frontend-service\", env=\"prod\"}"
      reason          = "Investigating latency spike - keep full fidelity"
    }
  }
}
