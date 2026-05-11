terraform {
  required_version = ">= 1.5"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

# The API enforces optimistic concurrency via the `version` field: a PUT with a
# stale version returns 409. If a rule is edited out-of-band (e.g. in the UI),
# bump var.rule_version on the caller side to reconcile.
resource "restapi_object" "this" {
  path = "/adaptive-logs/drop-rules"

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
