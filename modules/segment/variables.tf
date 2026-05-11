variable "name" {
  description = "Human-readable segment name."
  type        = string
}

variable "selector" {
  description = "LogQL selector. Only equality or multi-literal regex matchers are accepted by the API."
  type        = string
}
