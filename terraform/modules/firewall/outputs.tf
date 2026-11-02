output "rules_summary" {
  value = "22/tcp (ssh, restringido a: ${join(", ", var.allowed_ssh_cidrs)}), 80/tcp (http), 443/tcp (https) -- todo lo demas denegado por policy default de UFW"
}
