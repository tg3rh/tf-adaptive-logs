variable "rule" {
  description = "Drop rule definition."
  type = object({
    name              = string
    stream_selector   = string
    drop_rate         = number
    segment_id        = optional(string, "__global__")
    levels            = optional(list(string))
    log_line_contains = optional(list(string))
    disabled          = optional(bool, false)
    expires_at        = optional(string)
    rule_version      = optional(number, 1)
  })

  validation {
    condition     = startswith(var.rule.stream_selector, "{") && endswith(var.rule.stream_selector, "}")
    error_message = "stream_selector must be a LogQL stream selector beginning with '{' and ending with '}'."
  }

  validation {
    condition     = var.rule.drop_rate >= 0 && var.rule.drop_rate <= 100
    error_message = "drop_rate must be between 0 and 100."
  }

  validation {
    condition = var.rule.levels == null || alltrue([
      for l in coalesce(var.rule.levels, []) :
      contains(["trace", "debug", "info", "warn", "error", "critical", "fatal", "unknown"], l)
    ])
    error_message = "levels must be a subset of [trace, debug, info, warn, error, critical, fatal, unknown]."
  }

  validation {
    condition     = var.rule.expires_at == null || can(timeadd(var.rule.expires_at, "0s"))
    error_message = "expires_at must be an RFC3339 timestamp, e.g. 2026-07-01T00:00:00Z."
  }
}
