module "segments" {
  source   = "./modules/segment"
  for_each = var.segments

  name     = each.value.name
  selector = each.value.selector
}

module "drop_rules" {
  source   = "./modules/drop-rule"
  for_each = var.drop_rules

  rule = {
    name              = each.value.name
    stream_selector   = each.value.stream_selector
    drop_rate         = each.value.drop_rate
    segment_id        = try(module.segments[each.value.segment].id, each.value.segment)
    levels            = each.value.levels
    log_line_contains = each.value.log_line_contains
    disabled          = each.value.disabled
    expires_at        = each.value.expires_at
    rule_version      = each.value.rule_version
  }
}

module "exemptions" {
  source   = "./modules/exemption"
  for_each = var.exemptions

  stream_selector = each.value.stream_selector
  reason          = each.value.reason
  expires_at      = each.value.expires_at
}
