# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
  client_id = "39359ac3-9b2c-4cac-96df-ec246b0642b1"
  client_secret = "LzV2wIxf3vPZFCF5a-.~NwN-PP7.5nmV0p"
  tenant_id = "e9ba9f78-36bf-4339-9cc3-cd4adbbf19b3"
  subscription_id = "4fa1aa2a-bd64-49e7-a3cf-65127add0baa"
}
# Create a resource group if it doesn't exist
resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}
# Create virtual network
resource "azurerm_virtual_network" "alpha" {
    name                = "alphaVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus2"
    resource_group_name = "ssadcloud-RG"
    tags = {
        environment = "Demo"
    }
}
# Create subnet
resource "azurerm_subnet" "alpha" {
    name                 = "alphaSubnet"
    resource_group_name  = "ssadcloud-RG"
    virtual_network_name = azurerm_virtual_network.alpha.name
    address_prefixes     = ["10.0.1.0/24"]
}
# Create public IPs
resource "azurerm_public_ip" "alpha" {
    name                         = "alphaip"
    location                     = "eastus2"
    resource_group_name          = "ssadcloud-RG"
    allocation_method            = "Static"
    domain_name_label            = random_string.fqdn.result
    tags = {
        environment = "Demo"
    }
}
resource "azurerm_lb" "alpha" {
  name                = "alphaALB"
  location            = "eastus2"
  resource_group_name ="ssadcloud-RG"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.alpha.id
  }
}
resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id     = azurerm_lb.alpha.id
  name                = "BackEndAddressPool"
}
resource "azurerm_lb_probe" "alpha" {
  resource_group_name ="ssadcloud-RG"
  loadbalancer_id     = azurerm_lb.alpha.id
  name                = "http-probe"
  port                = 8080
}
#resource "azurerm_lb_nat_pool" "alpha" {
#  resource_group_name            = "ssadcloud-RG"
#  loadbalancer_id                = azurerm_lb.alpha.id
#  name                           = "ssh"
#  protocol                       = "Tcp"
#  frontend_port_start            = 80
#  backend_port                   = 80
#  frontend_ip_configuration_name = "PublicIPAddress"
#}
resource "azurerm_lb_rule" "alpha" {
  resource_group_name            = "ssadcloud-RG"
  loadbalancer_id                = azurerm_lb.alpha.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
}
data "azurerm_image" "iris-az-packer-image" {
  resource_group_name = "ssadcloud-RG"
  name                = "iris-az-packer-image"
}
resource "azurerm_virtual_machine_scale_set" "alpha" {
name                = "alpha-vmss"
location            = "eastus2"
resource_group_name ="ssadcloud-RG"
# automatic rolling upgrade
automatic_os_upgrade = false
upgrade_policy_mode  = "Manual"
sku {
  name     = "Standard_F2"
  tier     = "Standard"
  capacity = 2
}
storage_profile_image_reference {
id=data.azurerm_image.iris-az-packer-image.id
}
storage_profile_os_disk {
  name              = ""
  caching           = "ReadWrite"
  create_option     = "FromImage"
  managed_disk_type = "Standard_LRS"
}
storage_profile_data_disk {
  lun           = 0
  caching       = "ReadWrite"
  create_option = "Empty"
  disk_size_gb  = 10
}
os_profile {
  computer_name_prefix = "testvm"
  admin_username       = "ssadcloud"
}
os_profile_linux_config {
disable_password_authentication = true
ssh_keys {
path     = "/home/ssadcloud/.ssh/authorized_keys"
key_data = file("~/.ssh/id_rsa.pub")
}
}
network_profile {
      name    = "terraformnetworkprofile"
      primary = true

      ip_configuration {
        name                                   = "TestIPConfiguration"
        primary                                = true
        subnet_id                              = azurerm_subnet.alpha.id
        load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      }
}
}
