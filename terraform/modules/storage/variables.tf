variable "manage" {
  description = "true = Terraform crea los volúmenes; false = se asume que ya existen (adoptarlos con terraform import antes de poner esto en true)."
  type        = bool
}

variable "compose_project_name" {
  type = string
}
