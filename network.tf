resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${local.resource_suffix}-hub"
  address_space       = [var.virtual_network_address_space.hub]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${local.resource_suffix}-spoke"
  address_space       = [var.virtual_network_address_space.spoke]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_virtual_network_peering" "hub" {
  name                         = "peer-${azurerm_virtual_network.spoke.name}"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "spoke" {
  name                         = "peer-${azurerm_virtual_network.hub.name}"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = true
  use_remote_gateways          = true
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.hub.address_space[0], 1, 0)]
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.hub.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.hub.address_space[0], 1, 1)]
}

resource "azurerm_subnet" "workload" {
  name                 = "default"
  virtual_network_name = azurerm_virtual_network.spoke.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [cidrsubnet(azurerm_virtual_network.spoke.address_space[0], 0, 0)]
}

resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${local.resource_suffix}-bas"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowInternetInbound"
    priority                   = 100
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "AllowControlPlaneInbound"
    priority                   = 200
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    priority                   = 300
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "AzureLoadBalancer"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "AllowDataPlaneInbound"
    priority                   = 400
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["8080", "5701"]
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    protocol                   = "*"
    access                     = "Deny"
    direction                  = "Inbound"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }

  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 100
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Outbound"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_ranges    = ["22", "3389"]
  }

  security_rule {
    name                       = "AllowCloudOutbound"
    priority                   = 200
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Outbound"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "AzureCloud"
    destination_port_range     = "443"
  }

  security_rule {
    name                       = "AllowDataPlaneOutbound"
    priority                   = 300
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Outbound"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_ranges    = ["8080", "5701"]
  }

  security_rule {
    name                       = "AllowSessionCertificateValidationOutbound"
    priority                   = 400
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Outbound"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "Internet"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 1000
    protocol                   = "*"
    access                     = "Deny"
    direction                  = "Outbound"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  network_security_group_id = azurerm_network_security_group.bastion.id
  subnet_id                 = azurerm_subnet.bastion.id
}

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-${local.resource_suffix}-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  network_security_group_id = azurerm_network_security_group.workload.id
  subnet_id                 = azurerm_subnet.workload.id
}

resource "azurerm_public_ip_prefix" "main" {
  name                = "ippre-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix_length       = 31
  sku                 = "Standard"
}

resource "aws_vpc" "main" {
  cidr_block = var.aws_vpc_cidr_block
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.aws_vpc_cidr_block, 0, 0)
}

resource "aws_customer_gateway" "main" {
  ip_address = azurerm_public_ip.gateway.ip_address
  type       = "ipsec.1"
  bgp_asn    = 65000
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_vpn_connection" "main" {
  customer_gateway_id     = aws_customer_gateway.main.id
  vpn_gateway_id          = aws_vpn_gateway.main.id
  static_routes_only      = true
  local_ipv4_network_cidr = azurerm_subnet.workload.address_prefixes.0
  type                    = "ipsec.1"
}

resource "aws_vpn_gateway_attachment" "main" {
  vpc_id         = aws_vpc.main.id
  vpn_gateway_id = aws_vpn_gateway.main.id
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = azurerm_virtual_network.spoke.address_space.0
    gateway_id = aws_vpn_gateway.main.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_network_interface" "main" {
  subnet_id = aws_subnet.main.id
}

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }
}
