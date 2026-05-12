output "id" {
  description = "Server-generated drop rule ID."
  value       = restapi_object.this.id
}

output "data" {
  description = "JSON payload sent to the API. Useful for debugging and tests."
  value       = restapi_object.this.data
}
