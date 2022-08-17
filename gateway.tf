resource "azurerm_public_ip" "gateway" {
  name                = "pip-${local.resource_suffix}-vgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  public_ip_prefix_id = azurerm_public_ip_prefix.main.id
}

resource "azurerm_virtual_network_gateway" "main" {
  name                = "vgw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.gateway_sku
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = var.gateway_active_active
  enable_bgp          = var.gateway_enable_bgp
  generation          = var.gateway_generation

  ip_configuration {
    name                          = "default"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gateway.id
    subnet_id                     = azurerm_subnet.gateway.id
  }

  timeouts {
    create = "60m"
  }
}

resource "azurerm_local_network_gateway" "primary" {
  name                = "lgw-${local.resource_suffix}-pri"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  gateway_address     = aws_vpn_connection.main.tunnel1_address
  address_space       = [var.vpc_cidr_block]
}

resource "azurerm_local_network_gateway" "secondary" {
  name                = "lgw-${local.resource_suffix}-sec"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  gateway_address     = aws_vpn_connection.main.tunnel2_address
  address_space       = [var.vpc_cidr_block]
}

resource "azurerm_virtual_network_gateway_connection" "primary" {
  name                       = "con-${local.resource_suffix}-pri"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.primary.id
  shared_key                 = aws_vpn_connection.main.tunnel1_preshared_key
}

resource "azurerm_virtual_network_gateway_connection" "secondary" {
  name                       = "con-${local.resource_suffix}-sec"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.secondary.id
  shared_key                 = aws_vpn_connection.main.tunnel2_preshared_key
}

resource "aws_customer_gateway" "main" {
  ip_address = azurerm_public_ip.gateway.ip_address
  type       = "ipsec.1"
  bgp_asn    = 65000

  tags = {
    Name = local.global_resource_suffix
  }
}

resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.global_resource_suffix
  }
}

resource "aws_vpn_connection" "main" {
  customer_gateway_id = aws_customer_gateway.main.id
  vpn_gateway_id      = aws_vpn_gateway.main.id
  static_routes_only  = true
  type                = "ipsec.1"

  tags = {
    Name = local.global_resource_suffix
  }
}

resource "aws_vpn_connection_route" "main" {
  vpn_connection_id      = aws_vpn_connection.main.id
  destination_cidr_block = azurerm_virtual_network.spoke.address_space.0
}

resource "aws_vpn_gateway_attachment" "main" {
  vpc_id         = aws_vpc.main.id
  vpn_gateway_id = aws_vpn_gateway.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = azurerm_virtual_network.spoke.address_space.0
    gateway_id = aws_vpn_gateway.main.id
  }

  tags = {
    Name = local.global_resource_suffix
  }
}

resource "aws_route_table_association" "main" {
  route_table_id = aws_route_table.main.id
  subnet_id      = aws_subnet.main.id
}
