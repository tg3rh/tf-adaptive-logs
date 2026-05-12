locals {
  body_attrs = {
    stream_selector   = var.rule.stream_selector
    drop_rate         = var.rule.drop_rate
    levels            = var.rule.levels
    log_line_contains = var.rule.log_line_contains
  }

  rule_attrs = {
    segment_id = var.rule.segment_id
    name       = var.rule.name
    disabled   = var.rule.disabled
    version    = var.rule.rule_version
    expires_at = var.rule.expires_at
    body       = { for k, v in local.body_attrs : k => v if v != null }
  }

  payload = jsonencode({ for k, v in local.rule_attrs : k => v if v != null })
}

resource "restapi_object" "this" {
  path = "/adaptive-logs/drop-rules"

  ignore_changes_to = [
    "id",
    "tenant_id",
    "created_at",
    "updated_at",
  ]

  data = local.payload
}
