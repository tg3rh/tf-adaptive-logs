output "segment_ids" {
  description = "Map from segment key to server-generated segment ID."
  value       = { for k, m in module.segments : k => m.id }
}

output "drop_rule_ids" {
  description = "Map from drop-rule key to server-generated rule ID."
  value       = { for k, m in module.drop_rules : k => m.id }
}

output "exemption_ids" {
  description = "Map from exemption key to server-generated exemption ID."
  value       = { for k, m in module.exemptions : k => m.id }
}
