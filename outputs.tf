# -----------------------------------------
# outputs.tf
# -----------------------------------------

output "instance_public_ips" {
  value = [for i in oci_core_instance.gpu_instance : i.public_ip]
}

output "instance_private_keys" {
  value = [for i in range(var.instance_count) : "ssh_keys/server_${i + 1}"]
}

output "instance_names" {
  value = [for i in oci_core_instance.gpu_instance : i.display_name]
}

output "default_user" {
  value = "opc"
}
