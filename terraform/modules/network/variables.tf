variable "manage" {
  description = "true = Terraform crea la red; false = se asume que ya existe (adoptarla con terraform import antes de poner esto en true)."
  type        = bool
}

variable "compose_project_name" {
  type = string
}
