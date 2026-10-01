# Authentication: the Azure CLI session from `az login` (done by you in the browser).
# The subscription ID comes from ARM_SUBSCRIPTION_ID, set by scripts/azure.ps1 from
# `az account show`. No credentials are stored in this repo or in variables.
provider "azurerm" {
  features {
    virtual_machine {
      # On destroy, also delete the OS disk (no orphaned disk quietly using credit).
      delete_os_disk_on_deletion = true
    }
  }
  # Only register the core resource providers. Student subscriptions often can't
  # register the full set, and this config needs only Compute, Network and Storage.
  resource_provider_registrations = "core"
}
