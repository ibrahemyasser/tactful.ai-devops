variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "ibrahemyasser"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "tactful.ai-devops"
}
