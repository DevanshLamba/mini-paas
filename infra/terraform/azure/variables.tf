variable "location" {
  description = "Azure region. Must be one of the regions your Azure for Students policy allows."
  type        = string
  default     = "centralindia"
}

variable "allowed_locations" {
  description = "Regions allowed by the subscription's 'Allowed resource deployment regions' policy. scripts/azure.ps1 reads them after az login; an empty list skips the check (offline tests)."
  type        = list(string)
  default     = []
}

variable "ssh_allowed_cidr" {
  description = "The only source allowed to reach SSH (port 22): your public IP as a /32."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && endswith(var.ssh_allowed_cidr, "/32")
    error_message = "ssh_allowed_cidr must be a single IPv4 address in /32 form, e.g. 203.0.113.7/32."
  }
}

variable "ssh_public_key_path" {
  description = "Public key installed for the admin user."
  type        = string
  default     = "~/.ssh/minipaas_azure_ed25519.pub"
}

# ---- Credit guard rails: only small burstable sizes and a small disk can be planned. ----

variable "vm_size" {
  description = "VM size. B2als_v2 (2 vCPU / 4 GiB) is the cheapest size that fits k3s + Argo CD."
  type        = string
  default     = "Standard_B2als_v2"

  validation {
    condition     = contains(["Standard_B2als_v2", "Standard_B2s", "Standard_B2ats_v2"], var.vm_size)
    error_message = "Only Standard_B2als_v2, Standard_B2s or Standard_B2ats_v2 are allowed (credit guard rail)."
  }
}

variable "os_disk_gb" {
  description = "OS disk size in GiB (Standard SSD). 32 GiB = one E4 disk."
  type        = number
  default     = 32

  validation {
    condition     = var.os_disk_gb >= 30 && var.os_disk_gb <= 64
    error_message = "OS disk must be 30-64 GiB (credit guard rail)."
  }
}

variable "auto_shutdown_time" {
  description = "Daily automatic VM shutdown (HHMM, in auto_shutdown_timezone), a safety net if you forget to stop it. null disables it."
  type        = string
  default     = "2300"

  validation {
    condition     = var.auto_shutdown_time == null || can(regex("^([01][0-9]|2[0-3])[0-5][0-9]$", var.auto_shutdown_time))
    error_message = "auto_shutdown_time must be HHMM (e.g. 2300) or null."
  }
}

variable "auto_shutdown_timezone" {
  description = "Windows time zone ID for the auto-shutdown schedule."
  type        = string
  default     = "India Standard Time"
}

variable "k3s_version" {
  description = "Pinned k3s release (same Kubernetes minor as the local k3d cluster)."
  type        = string
  default     = "v1.36.5+k3s1"
}

variable "admin_username" {
  description = "Linux admin user (SSH key only; password login is disabled)."
  type        = string
  default     = "azureuser"
}

variable "name" {
  description = "Prefix for resource names."
  type        = string
  default     = "minipaas"
}
