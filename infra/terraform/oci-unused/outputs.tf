output "public_ip" {
  description = "Public IP of the k3s VM (HTTP/HTTPS open to the world; SSH only from ssh_allowed_cidr)."
  value       = oci_core_instance.k3s.public_ip
}

output "ssh_command" {
  description = "SSH into the VM."
  value       = "ssh -i ~/.ssh/minipaas_oci_ed25519 ubuntu@${oci_core_instance.k3s.public_ip}"
}

output "kube_api_tunnel" {
  description = "Reach the (non-public) Kubernetes API through SSH, then use kubeconfig ~/.kube/minipaas-oci.yaml."
  value       = "ssh -i ~/.ssh/minipaas_oci_ed25519 -N -L 16443:127.0.0.1:6443 ubuntu@${oci_core_instance.k3s.public_ip}"
}

output "image_name" {
  description = "Ubuntu image the VM was created from."
  value       = local.image_name
}

output "availability_domain" {
  value = local.availability_domain
}
