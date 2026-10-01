# Credentials come from ~/.oci/config (API signing key). Nothing secret lives in this repo,
# in variables or in state inputs. The region is read from the same profile.
provider "oci" {
  config_file_profile = var.oci_profile
}
