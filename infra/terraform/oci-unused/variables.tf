variable "oci_profile" {
  description = "Profile name in ~/.oci/config."
  type        = string
  default     = "DEFAULT"
}

variable "tenancy_ocid" {
  description = "Tenancy OCID (also used as the compartment). scripts/oci.ps1 reads it from ~/.oci/config."
  type        = string

  validation {
    condition     = startswith(var.tenancy_ocid, "ocid1.tenancy.")
    error_message = "tenancy_ocid must be a tenancy OCID (ocid1.tenancy...)."
  }
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
  description = "Path to the SSH public key installed for the 'ubuntu' user."
  type        = string
  default     = "~/.ssh/minipaas_oci_ed25519.pub"
}

variable "availability_domain" {
  description = "Exact availability domain name. Leave null to pick by index from the API."
  type        = string
  default     = null
}

variable "image_id" {
  description = "Pin a specific image OCID. Leave null to use the newest Ubuntu 24.04 aarch64 image."
  type        = string
  default     = null
}

variable "availability_domain_index" {
  description = "Which availability domain to use (0-based). Try another one if A1 capacity is unavailable."
  type        = number
  default     = 0
}

# ---- Always Free guard rails: these validations make it impossible to plan a paid size. ----

variable "ocpus" {
  description = "Ampere A1 OCPUs. Always Free: 2 OCPUs in total across all A1 instances."
  type        = number
  default     = 2

  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 2
    error_message = "Always Free allows at most 2 A1 OCPUs in total."
  }
}

variable "memory_gb" {
  description = "Ampere A1 memory in GB. Always Free: 12 GB in total across all A1 instances."
  type        = number
  default     = 12

  validation {
    condition     = var.memory_gb >= 1 && var.memory_gb <= 12
    error_message = "Always Free allows at most 12 GB of A1 memory in total."
  }
}

variable "boot_volume_gb" {
  description = "Boot volume size. Always Free: 200 GB of block+boot storage in total; minimum boot volume is 47 GB."
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_gb >= 47 && var.boot_volume_gb <= 200
    error_message = "Boot volume must be 47-200 GB to stay within the Always Free storage allowance."
  }
}

variable "k3s_version" {
  description = "Pinned k3s release (same Kubernetes minor as the local k3d cluster)."
  type        = string
  default     = "v1.36.5+k3s1"
}

variable "name" {
  description = "Prefix for resource display names."
  type        = string
  default     = "minipaas"
}
