terraform {
  required_version = ">= 1.5"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

resource "restapi_object" "this" {
  path = "/adaptive-logs/exemptions"

  data = jsonencode(merge(
    {
      stream_selector = var.stream_selector
    },
    var.reason != null ? { reason = var.reason } : {},
    var.expires_at != null ? { expires_at = var.expires_at } : {},
  ))
}
