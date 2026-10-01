terraform {
  # OpenTofu (open source, MPL) is the supported tool; Terraform also works unchanged.
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.7.0" # exact pin; .terraform.lock.hcl pins the checksums too
    }
  }

  # State is local (gitignored). See docs/phases/045-cloud.md for the risks.
}
