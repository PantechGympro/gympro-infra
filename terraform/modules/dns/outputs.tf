output "records" {
  value = [
    cloudflare_record.root.hostname,
    cloudflare_record.www.hostname,
    cloudflare_record.api.hostname,
  ]
}
