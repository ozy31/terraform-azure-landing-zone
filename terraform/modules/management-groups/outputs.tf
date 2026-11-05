output "ids" {
  description = "Management group resource IDs keyed by root, platform, landing-zones, sandbox, decommissioned, connectivity, management, identity, corp, online."
  value       = local.ids
}
