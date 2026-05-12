resource "restapi_object" "this" {
  path         = "/adaptive-logs/segment"
  read_path    = "/adaptive-logs/segment?segment={id}"
  update_path  = "/adaptive-logs/segment?segment={id}"
  destroy_path = "/adaptive-logs/segment?segment={id}"

  ignore_all_server_changes = true

  data = jsonencode({
    name     = var.name
    selector = var.selector
  })
}
