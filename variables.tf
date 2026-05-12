variable "segments" {
  description = "Map of Adaptive Logs segments to create. The map key is a local identifier referenced by drop_rules[].segment."
  type = map(object({
    name     = string
    selector = string
  }))
  default = {}
}

variable "drop_rules" {
  description = "Map of Adaptive Logs drop rules to create. The map key is a stable identifier you control. Set `segment` to a key from var.segments to scope the rule to that segment, to a literal segment ID, or omit it for tenant-wide."
  type = map(object({
    name              = string
    stream_selector   = string
    drop_rate         = number
    segment           = optional(string, "__global__")
    levels            = optional(list(string))
    log_line_contains = optional(list(string))
    disabled          = optional(bool, false)
    expires_at        = optional(string)
    rule_version      = optional(number, 1)
  }))
  default = {}
}

variable "exemptions" {
  description = "Map of Adaptive Logs exemptions to create. The map key is a stable identifier you control."
  type = map(object({
    stream_selector = string
    reason          = optional(string)
    expires_at      = optional(string)
  }))
  default = {}
}
