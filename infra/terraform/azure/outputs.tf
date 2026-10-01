output "public_ip" {
  description = "Public IP (SSH from ssh_allowed_cidr only; HTTP/HTTPS open)."
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/minipaas_azure_ed25519 ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "kube_api_tunnel" {
  description = "Reach the non-public Kubernetes API via SSH, then use ~/.kube/minipaas-azure.yaml."
  value       = "ssh -i ~/.ssh/minipaas_azure_ed25519 -N -L 16443:127.0.0.1:6443 ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "vm_size" {
  value = azurerm_linux_virtual_machine.k3s.size
}

output "location" {
  value = azurerm_resource_group.main.location
}
