# -----------------------------------------
# variables.tf
# -----------------------------------------

variable "compartment_id" {}
variable "availability_domain" {}
variable "subnet_id" {}
variable "image_id" {}
variable "instance_count" {
  default = 2
}

