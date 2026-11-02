output "docker_network_name" {
  description = "Nombre real de la red Docker administrada/adoptada para este entorno."
  value       = module.network.network_name
}

output "docker_volumes" {
  description = "Nombres reales de los volúmenes Docker administrados/adoptados (pg_data, mongo_data, ollama_models)."
  value       = module.storage.volume_names
}

output "firewall_rules_summary" {
  description = "Resumen legible de las reglas de firewall aplicadas en el host."
  value       = module.firewall.rules_summary
}

output "deploy_path" {
  description = "Ruta en el VPS donde se espera encontrar gympro-api/, gympro-web/ y gympro-infra/ como hermanos."
  value        = module.host_bootstrap.deploy_path
}
