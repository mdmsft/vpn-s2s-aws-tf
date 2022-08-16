variable "project" {
  type    = string
  default = "contoso"
}

variable "location" {
  type = object({
    name = string
    code = string
  })
  default = {
    name = "westeurope"
    code = "weu"
  }
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "virtual_network_address_space" {
  type = object({
    hub   = string
    spoke = string
  })
  default = {
    hub   = "192.168.0.0/24"
    spoke = "192.168.1.0/24"
  }
}

variable "bastion_scale_units" {
  type    = number
  default = 2
}

variable "workload_admin_username" {
  type    = string
  default = "azure"
}

variable "workload_size" {
  type    = string
  default = "Standard_B4ms"
}

variable "workload_image_reference" {
  type    = string
  default = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
}

variable "public_key_path" {
  type = string
}

variable "gateway_sku" {
  type    = string
  default = "VpnGw2"
}

variable "gateway_active_active" {
  type    = bool
  default = false
}

variable "gateway_enable_bgp" {
  type    = bool
  default = false
}

variable "gateway_generation" {
  type    = string
  default = "Generation2"
}

variable "gateway_address" {
  type    = string
  default = "1.2.3.4"
}

variable "local_network_address_space" {
  type    = string
  default = "192.168.255.0/24"
}

variable "aws_vpc_cidr_block" {
  type    = string
  default = "10.100.255.0/24"
}
