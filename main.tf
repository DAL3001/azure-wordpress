# Provider version requirements
terraform {


  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "vpzen"

    workspaces {
      name = "azure-wordpress"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.91.0"
    }
  }
}

#Use CLI creds for login
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "wordpress" {
  name     = "rg-wordpress-001"
  location = "UK South"
}

resource "azurerm_virtual_network" "wordpress" {
  name                = "vnet-wordpress"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.wordpress.name
  virtual_network_name = azurerm_virtual_network.wordpress.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "wordpress_server" {
  name                = "wordpress-server-001-nic"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name

  ip_configuration {
    name                          = "config1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "wordpress_server_001" {
  name                  = "vm-wordpress-server-001"
  location              = azurerm_resource_group.wordpress.location
  resource_group_name   = azurerm_resource_group.wordpress.name
  network_interface_ids = [azurerm_network_interface.wordpress_server.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk {
    name              = "datadisk1"
    create_option     = "Empty"
    disk_size_gb      = "20"
    lun               = 0
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "wp-server-001"
    admin_username = "admin"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("ssh/id_rsa.pub")
      path     = "/home/{username}/.ssh/authorized_keys"
    }
  }
  tags = {
    application = "wordpress"
    environment = "production"
  }
}
