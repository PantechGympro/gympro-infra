output "network_name" {
  value = var.manage ? docker_network.gympro[0].name : "${var.compose_project_name}_gympro"
}
