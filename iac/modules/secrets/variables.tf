variable "name" {
  type        = string
  description = "Secret name."
}

variable "description" {
  type        = string
  description = "Secret description."
  default     = "Application secret managed by Terraform."
}

variable "secret_value" {
  type        = map(string)
  description = "Secret payload."
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
