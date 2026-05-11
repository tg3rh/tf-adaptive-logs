variable "stream_selector" {
  description = "LogQL stream selector identifying logs that must not be dropped."
  type        = string
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
}
