# Offline tests: the OCI provider is mocked, so no credentials are needed and nothing is
# created. They prove the configuration plans the intended Always Free shape and that
# the guard rails reject anything that could cost money or widen SSH access.
# Run: terraform test   (or: tofu test)

mock_provider "oci" {}

variables {
  tenancy_ocid        = "ocid1.tenancy.oc1..mock"
  ssh_allowed_cidr    = "203.0.113.7/32"
  ssh_public_key_path = "tests/fixtures/test_key.pub"
  availability_domain = "xyz:EU-TEST-AD-1"
  image_id            = "ocid1.image.oc1..mock"
}

run "defaults_are_always_free" {
  command = plan

  assert {
    condition     = oci_core_instance.k3s.shape == "VM.Standard.A1.Flex"
    error_message = "Instance must use the Always Free Ampere A1 shape."
  }
  assert {
    condition     = oci_core_instance.k3s.shape_config[0].ocpus == 2 && oci_core_instance.k3s.shape_config[0].memory_in_gbs == 12
    error_message = "Expected 2 OCPU / 12 GB."
  }
  assert {
    condition     = tonumber(oci_core_instance.k3s.source_details[0].boot_volume_size_in_gbs) == 50
    error_message = "Expected a 50 GB boot volume."
  }
  assert {
    condition     = length([for r in oci_core_security_list.public.ingress_security_rules : r if r.source == "203.0.113.7/32"]) == 1
    error_message = "SSH must be restricted to ssh_allowed_cidr."
  }
  assert {
    condition = alltrue([
      for r in oci_core_security_list.public.ingress_security_rules :
      length(r.tcp_options) == 0 || !(r.tcp_options[0].min <= 6443 && r.tcp_options[0].max >= 6443)
    ])
    error_message = "The Kubernetes API port 6443 must not be opened in the security list."
  }
}

run "rejects_too_many_ocpus" {
  command = plan
  variables { ocpus = 4 }
  expect_failures = [var.ocpus]
}

run "rejects_too_much_memory" {
  command = plan
  variables { memory_gb = 24 }
  expect_failures = [var.memory_gb]
}

run "rejects_oversized_boot_volume" {
  command = plan
  variables { boot_volume_gb = 250 }
  expect_failures = [var.boot_volume_gb]
}

run "rejects_ssh_open_to_world" {
  command = plan
  variables { ssh_allowed_cidr = "0.0.0.0/0" }
  expect_failures = [var.ssh_allowed_cidr]
}
