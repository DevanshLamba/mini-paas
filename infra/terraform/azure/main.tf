locals {
  tags = {
    project    = "mini-paas"
    managed-by = "opentofu"
    purpose    = "student-demo-destroy-when-idle"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "${var.name}-rg"
  location = var.location
  tags     = local.tags

  lifecycle {
    precondition {
      condition     = length(var.allowed_locations) == 0 || contains(var.allowed_locations, var.location)
      error_message = "location '${var.location}' is not allowed by your subscription policy. Allowed: ${join(", ", var.allowed_locations)}."
    }
  }
}

# ---------------------------------------------------------------- network ----

resource "azurerm_virtual_network" "main" {
  name                = "${var.name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "main" {
  name                 = "${var.name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]
}

# The perimeter firewall. Only SSH (from one IP), HTTP and HTTPS get in. The Kubernetes
# API (6443) is never opened; it is reached through an SSH tunnel.
resource "azurerm_network_security_group" "main" {
  name                = "${var.name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh-operator"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.ssh_allowed_cidr
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "allow-http-https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["80", "443"]
  }

  # Already denied by Azure's default DenyAllInBound rule; stated explicitly so the
  # intent is reviewable and a later broad Allow rule can't silently expose it.
  security_rule {
    name                       = "deny-kube-api"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "6443"
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Needed for SSH. The app itself is reached through the Cloudflare Tunnel (outbound only).
resource "azurerm_public_ip" "main" {
  name                = "${var.name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "main" {
  name                = "${var.name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# ---------------------------------------------------------------- compute ----

resource "azurerm_linux_virtual_machine" "k3s" {
  name                  = "${var.name}-k3s"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.main.id]
  tags                  = local.tags

  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  }

  os_disk {
    name                 = "${var.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    k3s_version = var.k3s_version
  }))

  lifecycle {
    # Editing cloud-init later must not silently recreate (and wipe) the VM.
    ignore_changes = [custom_data]
  }
}

# Safety net: stop (deallocate) the VM every night in case it was left running.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "k3s" {
  count              = var.auto_shutdown_time == null ? 0 : 1
  virtual_machine_id = azurerm_linux_virtual_machine.k3s.id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }
}
