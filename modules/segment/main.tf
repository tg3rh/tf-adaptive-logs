terraform {
  required_version = ">= 1.5"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

# Segment endpoints use a query-string ID (?segment=<id>) rather than a path segment,
# so read/update/destroy paths must be overridden.
resource "restapi_object" "this" {
  path         = "/adaptive-logs/segment"
  read_path    = "/adaptive-logs/segment?segment={id}"
  update_path  = "/adaptive-logs/segment?segment={id}"
  destroy_path = "/adaptive-logs/segment?segment={id}"

  data = jsonencode({
    name     = var.name
    selector = var.selector
  })
}
