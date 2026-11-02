output "volume_names" {
  value = [for v in local.volume_names : "${var.compose_project_name}_${v}"]
}
