variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "recovery_window_in_days" {
  description = "Number of days to retain secret after deletion"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
