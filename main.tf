provider "azurerm" {
  features {}
  subscription_id = "98ecc27e-c9b7-4834-8660-82d8f8519be6"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-cloud-automation"
  location = "UK South"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-cloud-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-cloud-automation"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "public-ip-cloud-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"  # Set allocation method to Dynamic for Basic SKU
  sku                  = "Basic"    # Ensure the SKU is Basic for dynamic allocation
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-cloud-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-cloud-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                = "Standard_B1s"

  admin_username = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmos8XmTWEgovp6uq2rrHAz05uT/tQG851cJ1gZQ302 networkproject"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      software-properties-common

    # Add Docker’s official GPG key and repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
  EOF
  )
}
