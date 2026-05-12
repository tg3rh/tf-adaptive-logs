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
  path = "/adaptive-logs/drop-rules"

  ignore_changes_to = [
    "id",
    "tenant_id",
    "created_at",
    "updated_at",
  ]

  data = jsonencode(merge(
    {
      segment_id = var.segment_id
      name       = var.name
      disabled   = var.disabled
      version    = var.rule_version
      body = merge(
        {
          stream_selector = var.stream_selector
          drop_rate       = var.drop_rate
        },
        var.levels != null ? { levels = var.levels } : {},
        var.log_line_contains != null ? { log_line_contains = var.log_line_contains } : {},
      )
    },
    var.expires_at != null ? { expires_at = var.expires_at } : {},
  ))
}
