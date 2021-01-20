variable "user" {
  type = string
  default = "azureuser"
  description = "SSH user"
}

variable "password" {
  type = string
  default = "mysql@768!"
  description = "SSH user password"
}

variable "location" {
  type = string
  default = "eastus"
  description = "Location Azure"
}

terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.25.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

resource "azurerm_resource_group" "mysql_resource_group" {
    name     = "mysql_resource_group"
    location = var.location # Data Center Location
}

resource "azurerm_virtual_network" "mysql_vnet" {
    name                = "mysql_vnet"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.mysql_resource_group.name
}

resource "azurerm_subnet" "mysql_subnet" {
    name                 = "mysql_subnet"
    resource_group_name  = azurerm_resource_group.mysql_resource_group.name
    virtual_network_name = azurerm_virtual_network.mysql_vnet.name
    address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "mysql_public_ip" {
    name                         = "mysql_public_ip"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.mysql_resource_group.name
    allocation_method            = "Static"
    idle_timeout_in_minutes = 30
}

data "azurerm_public_ip" "mysql_public_ip_data" {
    name                = azurerm_public_ip.mysql_public_ip.name
    resource_group_name = azurerm_resource_group.mysql_resource_group.name
}

resource "azurerm_network_security_group" "mysql_nsg" {
    name                = "mysql_nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.mysql_resource_group.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "MYSQL"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3306"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "mysql_nic" {
    name                        = "mysql_nic"
    location                    = var.location
    resource_group_name         = azurerm_resource_group.mysql_resource_group.name

    ip_configuration {
        name                          = "mysql_nic_configuration"
        subnet_id                     = azurerm_subnet.mysql_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.mysql_public_ip.id
    }
}

resource "azurerm_network_interface_security_group_association" "mysql_nsga" {
    network_interface_id      = azurerm_network_interface.mysql_nic.id
    network_security_group_id = azurerm_network_security_group.mysql_nsg.id
}

resource "azurerm_storage_account" "mysql_storage" {
    name                        = "mysqlmbaimp" # possui limite de caracteres, precisa ser único entre TODA azure (!?)
    resource_group_name         = azurerm_resource_group.mysql_resource_group.name
    location                    = var.location
    account_replication_type    = "LRS"
    account_tier                = "Standard"
}

resource "azurerm_linux_virtual_machine" "mysql_vm" {
    name                  = "myVM"
    location              = var.location
    resource_group_name   = azurerm_resource_group.mysql_resource_group.name
    network_interface_ids = [azurerm_network_interface.mysql_nic.id]
    size                  = "Standard_B1ls"

    os_disk {
        name              = "mysqlDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "mysqlVm"
    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mysql_storage.primary_blob_endpoint
    }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [azurerm_linux_virtual_machine.mysql_vm]
  create_duration = "30s"
}

resource "null_resource" "upload" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.mysql_public_ip_data.ip_address
        }
        source = "./mysqld.cnf"
        destination = "/home/${var.user}/mysqld.cnf"
    }

    depends_on = [ time_sleep.wait_30_seconds ]
}

resource "null_resource" "deploy" {
    triggers = {
        order = null_resource.upload.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = data.azurerm_public_ip.mysql_public_ip_data.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo cp -f /home/${var.user}/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo mysql -u root -proot -e \"GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION; FLUSH PRIVILEGES;\"",
            "sudo service mysql restart",
            "sleep 20",
        ]
    }
}

output "public_id" {
  value = data.azurerm_public_ip.mysql_public_ip_data.ip_address 
}
