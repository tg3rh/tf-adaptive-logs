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

  # Exemption responses wrap the object under `result`: {"result":{"id":"...", ...}}.
  # Drop-rules and segments return flat objects, so they keep the provider default.
  id_attribute = "result/id"

  data = local.body
  # Without explicit update_data the provider would PUT whatever it has in state,
  # which after a read contains the `result`-wrapped response — and the API rejects
  # wrapped bodies with HTTP 500. Pinning update_data to the same flat body we sent
  # on create keeps PUTs valid.
  update_data = local.body

  # The Mastercard/restapi provider issues a PUT whenever ANY attribute changes —
  # even purely client-side ones like ignore_changes_to. Since the API rejects the
  # wrapped body that ends up in state after a read, every such PUT 500s. The only
  # safe option is to freeze the resource at create-time and force users to recreate
  # when they need to change anything:
  #   terraform apply -replace=module.<name>.restapi_object.this
  lifecycle {
    ignore_changes = all
  }
}

locals {
  body = jsonencode(merge(
    {
      stream_selector = var.stream_selector
    },
    var.reason != null ? { reason = var.reason } : {},
    var.expires_at != null ? { expires_at = var.expires_at } : {},
  ))
}
