# -----------------------------------------
# main.tf
# -----------------------------------------

provider "oci" {
  region = "us-ashburn-1" # Change to your region
}

resource "oci_core_instance" "gpu_instance" {
  count               = var.instance_count

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape               = "VM.GPU.A10.1"

  source_details {
    source_type = "image"
    source_id   = var.image_id
    
    boot_volume_size_in_gbs = 200
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = file("/home/opc/terraform-oci-gpu/ssh_keys/server_${count.index + 1}.pub")
  }

  display_name = "a10-gpu-${count.index + 1}"
}
