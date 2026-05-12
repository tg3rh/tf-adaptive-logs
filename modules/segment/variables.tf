variable "name" {
  description = "Human-readable segment name."
  type        = string
}

variable "selector" {
  description = "LogQL selector. Only equality or multi-literal regex matchers are accepted by the API."
  type        = string

  validation {
    condition     = startswith(var.selector, "{") && endswith(var.selector, "}")
    error_message = "selector must be a LogQL selector beginning with '{' and ending with '}'."
  }
}
