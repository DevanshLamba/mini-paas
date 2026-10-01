# One VCN with one public subnet. All Always Free (a Free Tier tenancy may have 2 VCNs).

resource "oci_core_vcn" "main" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.name}-vcn"
  cidr_blocks    = ["10.10.0.0/16"]
  dns_label      = var.name
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# The perimeter firewall. Only SSH (from one IP), HTTP and HTTPS get in.
# The Kubernetes API (6443) is deliberately NOT listed: it is reached through an SSH tunnel.
resource "oci_core_security_list" "public" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.name}-public-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Outbound: OS updates, image pulls from ghcr.io, git polling by Argo CD"
  }

  ingress_security_rules {
    source      = var.ssh_allowed_cidr
    protocol    = "6" # TCP
    description = "SSH from the operator's IP only"
    tcp_options {
      min = 22
      max = 22
    }
  }

  dynamic "ingress_security_rules" {
    for_each = { http = 80, https = 443 }
    content {
      source      = "0.0.0.0/0"
      protocol    = "6"
      description = "${upper(ingress_security_rules.key)} to the Traefik ingress"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  # ICMP "fragmentation needed" keeps Path MTU discovery working (otherwise some TCP
  # connections hang). Same as Oracle's default security list.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1" # ICMP
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    source   = oci_core_vcn.main.cidr_blocks[0]
    protocol = "1"
    icmp_options {
      type = 3
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.tenancy_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${var.name}-public-subnet"
  cidr_block                 = "10.10.1.0/24"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
}
