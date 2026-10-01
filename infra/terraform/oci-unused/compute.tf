# Looked up only when not pinned via variables (tests pin them, so they need no API calls).
data "oci_identity_availability_domains" "ads" {
  count          = var.availability_domain == null ? 1 : 0
  compartment_id = var.tenancy_ocid
}

# Newest Canonical Ubuntu 24.04 image that supports the A1 (arm64) shape.
data "oci_core_images" "ubuntu_arm" {
  count                    = var.image_id == null ? 1 : 0
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  availability_domain = coalesce(var.availability_domain, try(data.oci_identity_availability_domains.ads[0].availability_domains[var.availability_domain_index].name, null))
  image_id            = coalesce(var.image_id, try(data.oci_core_images.ubuntu_arm[0].images[0].id, null))
  image_name          = var.image_id != null ? "(pinned) ${var.image_id}" : try(data.oci_core_images.ubuntu_arm[0].images[0].display_name, "unknown")
}

resource "oci_core_instance" "k3s" {
  compartment_id      = var.tenancy_ocid
  availability_domain = local.availability_domain
  display_name        = "${var.name}-k3s"
  shape               = "VM.Standard.A1.Flex" # Always Free eligible (Ampere A1, arm64)

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "k3s"
  }

  # Only IMDSv2-style metadata access (blocks a common SSRF credential-theft path).
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(pathexpand(var.ssh_public_key_path)))
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      k3s_version = var.k3s_version
    }))
  }

  # A new image release must not silently replace (and wipe) the running VM.
  lifecycle {
    ignore_changes = [source_details[0].source_id, metadata["user_data"]]
  }
}
