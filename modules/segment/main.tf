resource "restapi_object" "this" {
  path         = "/adaptive-logs/segment"
  read_path    = "/adaptive-logs/segment?segment={id}"
  update_path  = "/adaptive-logs/segment?segment={id}"
  destroy_path = "/adaptive-logs/segment?segment={id}"

  ignore_changes_to = [
    "id",
    "created_at",
    "updated_at",
    "is_early",
    "fallback_to_default",
  ]

  data = jsonencode({
    name     = var.name
    selector = var.selector
  })
}
