variable "vps_host" {
  type = string
}

variable "vps_ssh_user" {
  type = string
}

variable "vps_ssh_port" {
  type = number
}

variable "deploy_path" {
  type = string
}

variable "runtime_dirs" {
  type = list(string)
}
