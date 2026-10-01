terraform {
  # Works with Terraform (BSL) and OpenTofu (MPL, open source); the code is identical.
  required_version = ">= 1.9.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "= 9.8.0" # exact pin; .terraform.lock.hcl pins the checksums too
    }
  }

  # State is kept locally in this directory (gitignored). See docs/phases/045-cloud.md
  # for the risks and the remote-state alternative.
}
