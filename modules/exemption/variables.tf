variable "stream_selector" {
  description = "LogQL stream selector identifying logs that must not be dropped."
  type        = string

  validation {
    condition     = startswith(var.stream_selector, "{") && endswith(var.stream_selector, "}")
    error_message = "stream_selector must be a LogQL stream selector beginning with '{' and ending with '}'."
  }
}

variable "reason" {
  description = "Business justification recorded with the exemption."
  type        = string
  default     = null
}

variable "expires_at" {
  description = "RFC3339 expiration timestamp. Permanent if null."
  type        = string
  default     = null

  validation {
    condition     = var.expires_at == null || can(timeadd(var.expires_at, "0s"))
    error_message = "expires_at must be an RFC3339 timestamp, e.g. 2026-07-01T00:00:00Z."
  }
}
