resource "restapi_object" "this" {
  path         = "/adaptive-logs/exemptions"
  id_attribute = "result/id"
  data         = local.body
  update_data  = local.body

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
