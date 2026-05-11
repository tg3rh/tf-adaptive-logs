output "id" {
  description = "Server-generated segment ID. Pass this to drop-rule modules as segment_id."
  value       = restapi_object.this.id
}

output "name" {
  description = "Segment name as stored on the server."
  value       = var.name
}
