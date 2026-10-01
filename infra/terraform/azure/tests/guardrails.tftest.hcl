# Offline tests: the azurerm provider is mocked, so no Azure login is needed and nothing
# is created. They prove the plan uses the intended small VM and closed perimeter, and
# that the guard rails reject anything that could burn credit or widen SSH access.
# Run: tofu test   (or: terraform test)

# Mocked IDs must look like real Azure resource IDs: azurerm validates their format.
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg/providers/Microsoft.Network/virtualNetworks/minipaas-vnet" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg/providers/Microsoft.Network/virtualNetworks/minipaas-vnet/subnets/minipaas-subnet" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg/providers/Microsoft.Network/networkSecurityGroups/minipaas-nsg" }
  }
  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg/providers/Microsoft.Network/publicIPAddresses/minipaas-pip" }
  }
  mock_resource "azurerm_network_interface" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg/providers/Microsoft.Network/networkInterfaces/minipaas-nic" }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/minipaas-rg/providers/Microsoft.Compute/virtualMachines/minipaas-k3s" }
  }
}

variables {
  ssh_allowed_cidr    = "203.0.113.7/32"
  ssh_public_key_path = "tests/fixtures/test_key.pub"
}

run "defaults_are_small_and_closed" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.k3s.size == "Standard_B2als_v2"
    error_message = "Default VM size must be Standard_B2als_v2."
  }
  assert {
    condition     = azurerm_linux_virtual_machine.k3s.os_disk[0].disk_size_gb == 32 && azurerm_linux_virtual_machine.k3s.os_disk[0].storage_account_type == "StandardSSD_LRS"
    error_message = "Expected a 32 GiB Standard SSD OS disk."
  }
  assert {
    condition     = azurerm_linux_virtual_machine.k3s.disable_password_authentication
    error_message = "Password authentication must be disabled."
  }
  assert {
    condition = one([
      for r in azurerm_network_security_group.main.security_rule : r.source_address_prefix
      if r.destination_port_range == "22" && r.access == "Allow"
    ]) == "203.0.113.7/32"
    error_message = "SSH must be allowed only from ssh_allowed_cidr."
  }
  assert {
    condition = length([
      for r in azurerm_network_security_group.main.security_rule : r
      if r.access == "Allow" && (r.destination_port_range == "6443" || contains(coalesce(r.destination_port_ranges, []), "6443"))
    ]) == 0
    error_message = "The Kubernetes API port 6443 must never be allowed."
  }
  assert {
    condition     = length(azurerm_dev_test_global_vm_shutdown_schedule.k3s) == 1
    error_message = "The nightly auto-shutdown safety net must be on by default."
  }
}

run "rejects_large_vm" {
  command = plan
  variables { vm_size = "Standard_D4s_v5" }
  expect_failures = [var.vm_size]
}

run "rejects_large_disk" {
  command = plan
  variables { os_disk_gb = 256 }
  expect_failures = [var.os_disk_gb]
}

run "rejects_ssh_open_to_world" {
  command = plan
  variables { ssh_allowed_cidr = "0.0.0.0/0" }
  expect_failures = [var.ssh_allowed_cidr]
}

run "rejects_disallowed_region" {
  command = plan
  variables {
    location          = "westus"
    allowed_locations = ["centralindia", "southeastasia"]
  }
  expect_failures = [azurerm_resource_group.main]
}
