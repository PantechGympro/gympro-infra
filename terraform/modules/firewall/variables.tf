variable "vps_host" {
  type = string
}

variable "vps_ssh_user" {
  type = string
}

variable "vps_ssh_port" {
  type = number
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}
