output "id" {
  description = "Server-generated segment ID. Pass this to drop-rule modules as segment_id."
  value       = restapi_object.this.id
}

output "name" {
  description = "Segment name as stored on the server."
  value       = var.name
}

output "data" {
  description = "JSON payload sent to the API. Useful for debugging and tests."
  value       = restapi_object.this.data
}
