variable "segment_id" {
  description = "Target segment ID. Use \"__global__\" for tenant-wide rules."
  type        = string
  default     = "__global__"
}

variable "name" {
  description = "Human-readable rule name."
  type        = string
}

variable "stream_selector" {
  description = "LogQL stream selector matching the logs this rule applies to."
  type        = string
}

variable "drop_rate" {
  description = "Percentage of matching log lines to drop (0-100)."
  type        = number

  validation {
    condition     = var.drop_rate >= 0 && var.drop_rate <= 100
    error_message = "drop_rate must be between 0 and 100."
  }
}

variable "levels" {
  description = "Optional list of log levels to match (e.g. [\"info\", \"debug\"]). Omit to match all levels."
  type        = list(string)
  default     = null
}

variable "log_line_contains" {
  description = "Optional list of substrings required in the log line for the rule to match."
  type        = list(string)
  default     = null
}

variable "disabled" {
  description = "Create the rule in a disabled state."
  type        = bool
  default     = false
}

variable "expires_at" {
  description = "RFC3339 timestamp at which the rule stops applying. Permanent if null."
  type        = string
  default     = null
}

variable "rule_version" {
  description = "Optimistic-concurrency version sent to the API as `version`. Bump if the rule was edited out-of-band and the next apply 409s. (Renamed from `version` because that name is reserved by Terraform inside module blocks.)"
  type        = number
  default     = 1
}
