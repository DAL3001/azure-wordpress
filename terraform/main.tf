# Provider version requirements
terraform {


  backend "azurerm" {
    resource_group_name  = "rg-terraform-states"
    storage_account_name = "tfstate135564"
    container_name       = "tfstate"
    key                  = "wordpress.terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.91.0"
    }
  }
}

#Use CLI creds for login if running locally
provider "azurerm" {
  features {}
}

# Resource group for all wordpress stuff
resource "azurerm_resource_group" "wordpress" {
  name     = "rg-wordpress-001"
  location = "UK South"
}

# VNet creation
resource "azurerm_virtual_network" "wordpress" {
  name                = "vnet-wordpress"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet in the VNet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.wordpress.name
  virtual_network_name = azurerm_virtual_network.wordpress.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Provision a public IP we can attach to the VM's NIC later
resource "azurerm_public_ip" "wordpress_server" {
  name                = "pip-wordpress-server-001"
  resource_group_name = azurerm_resource_group.wordpress.name
  location            = azurerm_resource_group.wordpress.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

# Create a NIC for the VM and associate the public IP with it. Set a DHCP assigned private address. 
resource "azurerm_network_interface" "wordpress_server" {
  name                = "wordpress-server-001-nic"
  location            = azurerm_resource_group.wordpress.location
  resource_group_name = azurerm_resource_group.wordpress.name

  ip_configuration {
    name                          = "config1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wordpress_server.id
  }
}

# Provision a managed disk we can attach to the VM to use a /data storage
resource "azurerm_managed_disk" "wordpress_server_data" {
  name                 = "wordpress-server-001-disk1"
  location             = azurerm_resource_group.wordpress.location
  resource_group_name  = azurerm_resource_group.wordpress.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 20
}

# Attach it to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "wordpress_server" {
  managed_disk_id    = azurerm_managed_disk.wordpress_server_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.wordpress_server_001.id
  lun                = "10"
  caching            = "ReadWrite"
}

# Configuration for the VM itself, set a user up and pass the public key to use for SSH auth
resource "azurerm_linux_virtual_machine" "wordpress_server_001" {
  name                            = "vm-wordpress-server-001"
  location                        = azurerm_resource_group.wordpress.location
  resource_group_name             = azurerm_resource_group.wordpress.name
  network_interface_ids           = [azurerm_network_interface.wordpress_server.id]
  size                            = "Standard_B1lssss"
  admin_username                  = "wpadmin"
  disable_password_authentication = true
  patch_mode                      = "AutomaticByPlatform"

  admin_ssh_key {
    username   = "wpadmin"
    public_key = file("${path.module}/../ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "osdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    application = "wordpress"
    environment = "production"
  }
}


# Output an ansible inventory file

resource "local_file" "tf_ansible_inventory" {
  content = <<-DOC
all:
  hosts:
    wordpress_server_001:
      ansible_host: ${azurerm_public_ip.wordpress_server.ip_address}
  vars:
    wordpress_admin: ${azurerm_linux_virtual_machine.wordpress_server_001.admin_username}
    DOC
  filename = "../ansible/inventory"
}