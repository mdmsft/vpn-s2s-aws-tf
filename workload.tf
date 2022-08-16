locals {
  workload_image_reference = split(":", var.workload_image_reference)
}

resource "azurerm_network_interface" "main" {
  name                    = "nic-${local.resource_suffix}"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  internal_dns_name_label = "workload"

  ip_configuration {
    name                          = "primary"
    primary                       = true
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_ssh_public_key" "main" {
  name                = "ssh-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  public_key          = file(var.public_key_path)
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vm-${local.resource_suffix}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  computer_name                   = "workload"
  admin_username                  = var.workload_admin_username
  disable_password_authentication = true
  size                            = var.workload_size
  custom_data                     = base64encode(templatefile("${path.module}/cloud-config.yaml", {}))

  network_interface_ids = [
    azurerm_network_interface.main.id
  ]

  admin_ssh_key {
    username   = var.workload_admin_username
    public_key = azurerm_ssh_public_key.main.public_key
  }

  os_disk {
    name                 = "osdisk-${local.resource_suffix}"
    disk_size_gb         = 32
    caching              = "ReadOnly"
    storage_account_type = "Standard_LRS"

    diff_disk_settings {
      placement = "ResourceDisk"
      option    = "Local"
    }
  }

  source_image_reference {
    publisher = local.workload_image_reference.0
    offer     = local.workload_image_reference.1
    sku       = local.workload_image_reference.2
    version   = local.workload_image_reference.3
  }
}
