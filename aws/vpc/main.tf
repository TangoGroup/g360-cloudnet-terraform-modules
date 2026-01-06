################################################################################
# Data Sources
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  cidr_block = var.cidr

  assign_generated_ipv6_cidr_block = var.enable_ipv6 ? true : null

  instance_tenancy               = var.instance_tenancy
  enable_dns_hostnames           = var.enable_dns_hostnames
  enable_dns_support             = var.enable_dns_support

  tags = merge(
    local.tags,
    var.vpc_tags,
    { "Name" = local.name },
  )
}

# Separate resource for IPv6 CIDR block association when explicitly provided
resource "aws_vpc_ipv6_cidr_block_association" "this" {
  count = var.ipv6_cidr != null ? 1 : 0

  vpc_id         = aws_vpc.this.id
  ipv6_cidr_block = var.ipv6_cidr
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.this.id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      self             = lookup(ingress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(ingress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(ingress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(ingress.value, "security_groups", "")))
      description      = lookup(ingress.value, "description", null)
      from_port        = lookup(ingress.value, "from_port", 0)
      to_port          = lookup(ingress.value, "to_port", 0)
      protocol         = lookup(ingress.value, "protocol", "-1")
    }
  }

  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      self             = lookup(egress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(egress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(egress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(egress.value, "security_groups", "")))
      description      = lookup(egress.value, "description", null)
      from_port        = lookup(egress.value, "from_port", 0)
      to_port          = lookup(egress.value, "to_port", 0)
      protocol         = lookup(egress.value, "protocol", "-1")
    }
  }

  tags = merge(
    local.tags,
    var.default_security_group_tags,
    { "Name" = coalesce(var.default_security_group_name, local.name) },
  )
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(
    { "Name" = local.name },
    local.tags,
    var.dhcp_options_tags,
  )
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = local.name },
    local.tags,
    var.igw_tags,
  )
}

resource "aws_egress_only_internet_gateway" "this" {
  count = var.create_egress_only_igw && var.enable_ipv6 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = local.name },
    local.tags,
    var.igw_tags,
  )
}

################################################################################
# Default route
################################################################################
resource "aws_default_route_table" "default" {
  count = var.manage_default_route_table ? 1 : 0

  default_route_table_id = aws_vpc.this.default_route_table_id

  dynamic "route" {
    for_each = var.default_route_table_routes
    content {
      # One of the following destinations must be provided
      cidr_block      = route.value.cidr_block
      ipv6_cidr_block = lookup(route.value, "ipv6_cidr_block", null)

      # One of the following targets must be provided
      egress_only_gateway_id    = lookup(route.value, "egress_only_gateway_id", null)
      gateway_id                = lookup(route.value, "gateway_id", null)
      instance_id               = lookup(route.value, "instance_id", null)
      nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
      network_interface_id      = lookup(route.value, "network_interface_id", null)
      transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
      vpc_endpoint_id           = lookup(route.value, "vpc_endpoint_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  tags = merge(
    local.tags,
    var.default_route_table_tags,
    { "Name" = "${local.name}-default" },
  )
}

################################################################################
# Publiс routes
# One public route table for all public subnets.
################################################################################
resource "aws_route_table" "public" {
  for_each = length(var.public_subnets) > 0 ? var.public_subnets : {}

  vpc_id = local.vpc_id

  tags = merge(
    local.tags,
    var.public_route_table_tags,
    { Name = lookup(each.value, "name", null) != null ? "${each.value.name}" : "${local.name}-${var.public_subnet_suffix}-${each.value.az}" }
  )
}

resource "aws_route" "public_internet_gateway" {
  for_each = var.create_igw && length(var.public_subnets) > 0 ? var.public_subnets : {}

  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "public_internet_gateway_ipv6" {
  for_each = var.create_igw && var.enable_ipv6 && length(var.public_subnets) > 0 ? var.public_subnets : {}

  route_table_id              = aws_route_table.public[each.key].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this[0].id
}

################################################################################
# Private routes
# There are as many private route tables as the number of private subnets
################################################################################
resource "aws_route_table" "private" {
  for_each = length(var.private_subnets) > 0 ? var.private_subnets : {}

  vpc_id = local.vpc_id

  tags = merge(
    local.tags,
    var.private_route_table_tags,
    { Name = lookup(each.value, "name", null) != null ? "${each.value.name}" : "${local.name}-${each.value.az}-${var.private_subnet_suffix}" }
  )
}

resource "aws_route" "private_nat_gateway" {
  for_each = var.enable_nat_gateway && !(var.enable_transit_gateway) && length(var.private_subnets) > 0 ? var.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = var.nat_gateway_destination_cidr_block #0.0.0.0/0 by default.
  nat_gateway_id         = !(var.one_nat_gateway_per_az) ? aws_nat_gateway.this[0].id : local.availability_zone_nat_gateways[local.availability_zone_public_subnets[each.value.az][0]][0]

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_transit_gateway" {
  for_each = var.enable_transit_gateway && !(var.enable_nat_gateway) && length(var.private_subnets) > 0 ? var.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = var.transit_gateway_destination_cidr_block #0.0.0.0/0 by default.
  transit_gateway_id     = var.transit_gateway_id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_custom_routes" {
  for_each = length(local.private_subnets_routes) > 0 ? local.private_subnets_routes : {}

  route_table_id         = aws_route_table.private[each.value.source_cidr_block].id
  destination_cidr_block = each.value.destination_cidr_block
  # One of the following targets must be provided
  egress_only_gateway_id    = lookup(each.value, "egress_only_gateway_id", null)
  gateway_id                = lookup(each.value, "gateway_id", null)
  # instance_id               = lookup(each.value, "instance_id", null)
  nat_gateway_id            = lookup(each.value, "nat_gateway_id", null)
  network_interface_id      = lookup(each.value, "network_interface_id", null)
  transit_gateway_id        = lookup(each.value, "transit_gateway_id", null)
  vpc_endpoint_id           = lookup(each.value, "vpc_endpoint_id", null)
  vpc_peering_connection_id = lookup(each.value, "vpc_peering_connection_id", null)

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_ipv6_egress" {
  for_each = var.create_egress_only_igw && var.enable_ipv6 ? var.private_subnets : {}

  route_table_id              = aws_route_table.private[each.key].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = element(aws_egress_only_internet_gateway.this[*].id, 0)
}

################################################################################
# Database routes
################################################################################
resource "aws_route_table" "database" {
  for_each = length(var.database_subnets) > 0 ? var.database_subnets : {}

  vpc_id = local.vpc_id

  tags = merge(
    local.tags,
    var.database_route_table_tags,
    { "Name" = "${local.name}-${var.database_subnet_suffix}-${each.value.az}" },
  )
}

resource "aws_route" "database_internet_gateway" {
  count    = var.create_igw && var.create_database_subnet_route_table && length(var.database_subnets) > 0 && var.create_database_internet_gateway_route && !(var.create_database_nat_gateway_route) ? 1 : 0

  route_table_id         = aws_route_table.database[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "database_nat_gateway" {
  for_each = var.create_database_subnet_route_table && length(var.database_subnets) > 0 && !(var.create_database_internet_gateway_route) && var.create_database_nat_gateway_route && var.enable_nat_gateway ? var.database_subnets : {}

  route_table_id         = aws_route_table.database[each.key].id
  destination_cidr_block = var.nat_gateway_destination_cidr_block #0.0.0.0/0 by default.
  nat_gateway_id         = !(var.one_nat_gateway_per_az) ? aws_nat_gateway.this[0].id : local.availability_zone_nat_gateways[local.availability_zone_public_subnets[each.value.az][0]][0]

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "database_ipv6_egress" {
  for_each = var.create_egress_only_igw && var.enable_ipv6 && var.create_database_subnet_route_table && length(var.database_subnets) > 0 && var.create_database_internet_gateway_route ?  var.database_subnets : {}

  route_table_id              = aws_route_table.database[each.key].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = element(aws_egress_only_internet_gateway.this[*].id, 0)

  timeouts {
    create = "5m"
  }
}

################################################################################
# Elasticache routes
################################################################################

resource "aws_route_table" "elasticache" {
  for_each = length(var.elasticache_subnets) > 0 ? var.elasticache_subnets : {}

  vpc_id = local.vpc_id

  tags = merge(
    local.tags,
    var.elasticache_route_table_tags,
    { "Name" = "${local.name}-${var.elasticache_subnet_suffix}-${each.value.az}" },
  )
}

################################################################################
# Isolated routes
################################################################################

resource "aws_route_table" "isolated" {
  for_each = length(var.isolated_subnets) > 0 ? var.isolated_subnets : {}

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${local.name}-${var.isolated_subnet_suffix}-${each.value.az}" },
    local.tags,
    var.isolated_route_table_tags,
  )
}

resource "aws_route" "isolated_custom_routes" {
  for_each = length(local.isolated_subnets_routes) > 0 ? local.isolated_subnets_routes : {}

  route_table_id         = aws_route_table.isolated[each.value.source_cidr_block].id
  destination_cidr_block = each.value.destination_cidr_block
  # One of the following targets must be provided
  egress_only_gateway_id    = lookup(each.value, "egress_only_gateway_id", null)
  gateway_id                = lookup(each.value, "gateway_id", null)
  # instance_id               = lookup(each.value, "instance_id", null)
  nat_gateway_id            = lookup(each.value, "nat_gateway_id", null)
  network_interface_id      = lookup(each.value, "network_interface_id", null)
  transit_gateway_id        = lookup(each.value, "transit_gateway_id", null)
  vpc_endpoint_id           = lookup(each.value, "vpc_endpoint_id", null)
  vpc_peering_connection_id = lookup(each.value, "vpc_peering_connection_id", null)

  timeouts {
    create = "5m"
  }
}

################################################################################
# Kubernetes routes
################################################################################

resource "aws_route_table" "kubernetes" {
  for_each = length(var.kubernetes_subnets) > 0 ? var.kubernetes_subnets : {}

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${local.name}-${var.kubernetes_subnet_suffix}-${each.value.az}" },
    local.tags,
    var.kubernetes_route_table_tags,
  )
}

resource "aws_route" "kubernetes_nat_gateway" {
  for_each = var.enable_nat_gateway && !(var.enable_transit_gateway) && length(var.kubernetes_subnets) > 0 ? var.kubernetes_subnets : {}

  route_table_id         = aws_route_table.kubernetes[each.key].id
  destination_cidr_block = var.nat_gateway_destination_cidr_block #0.0.0.0/0 by default.
  nat_gateway_id         = !(var.one_nat_gateway_per_az) ? aws_nat_gateway.this[0].id : local.availability_zone_nat_gateways[local.availability_zone_public_subnets[each.value.az][0]][0]

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "kubernetes_transit_gateway" {
  for_each = var.enable_transit_gateway && !(var.enable_nat_gateway) && length(var.kubernetes_subnets) > 0 ? var.kubernetes_subnets : {}

  route_table_id         = aws_route_table.kubernetes[each.key].id
  destination_cidr_block = var.transit_gateway_destination_cidr_block #0.0.0.0/0 by default.
  transit_gateway_id     = var.transit_gateway_id

  timeouts {
    create = "5m"
  }
}

################################################################################
# Public subnet
################################################################################

resource "aws_subnet" "public" {
  for_each = length(var.public_subnets) > 0 ? var.public_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]

  map_public_ip_on_launch         = var.map_public_ip_on_launch
  assign_ipv6_address_on_creation = var.public_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.public_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.public_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.public_subnet_ipv6_prefixes[index(var.public_subnets, each.key)]) : null

  tags = merge(
    local.tags,
    var.public_subnet_tags,
    lookup(var.public_subnet_tags_per_az, each.value.az, {}),
    each.value.tags,
    {
      Name             = lookup(each.value, "name", "") != "" ? "${each.value.name}" : "${local.name}-${var.public_subnet_suffix}-${each.value.az}"
      security_posture = "public"
    }
  )
}

################################################################################
# Private subnet
################################################################################
resource "aws_subnet" "private" {
  for_each = length(var.private_subnets) > 0 ? var.private_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]

  assign_ipv6_address_on_creation = var.private_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.private_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.private_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.private_subnet_ipv6_prefixes[index(var.private_subnets, each.key)]) : null

  tags = merge(
    local.tags,
    var.private_subnet_tags,
    lookup(var.private_subnet_tags_per_az, each.value.az, {}),
    each.value.tags,
    {
      Name = lookup(each.value, "name", null) != null ? "${each.value.name}" : "${local.name}-${var.private_subnet_suffix}-${each.value.az}"
      security_posture = "private"
    },
  )
}

################################################################################
# Database subnet
################################################################################

resource "aws_subnet" "database" {
  for_each = length(var.database_subnets) > 0 ? var.database_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]
  assign_ipv6_address_on_creation = var.database_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.database_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.database_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.database_subnet_ipv6_prefixes[index(var.database_subnets, each.key)]) : null

  tags = merge(
    local.tags,
    var.database_subnet_tags,
    each.value.tags,
    {
      Name = lookup(each.value, "name", "") != "" ? "${each.value.name}" : "${local.name}-${var.database_subnet_suffix}-${each.value.az}"
      security_posture = "private"
    },
  )
}

resource "aws_db_subnet_group" "database" {
  count = length(var.database_subnets) > 0 && var.create_database_subnet_group ? 1 : 0

  name        = lower(coalesce(var.database_subnet_group_name, local.name))
  description = "Database subnet group for ${local.name}"
  subnet_ids  = [ for subnet in aws_subnet.database : subnet.id ]

  tags = merge(
    local.tags,
    var.database_subnet_group_tags,
    {
      "Name" = lower(coalesce(var.database_subnet_group_name, local.name))
    },
  )
}

################################################################################
# Kubernetes subnet
################################################################################

resource "aws_subnet" "kubernetes" {
  for_each = length(var.kubernetes_subnets) > 0 ? var.kubernetes_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]
  assign_ipv6_address_on_creation = var.kubernetes_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.kubernetes_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.kubernetes_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.kubernetes_subnet_ipv6_prefixes[index(var.kubernetes_subnets, each.key)]) : null

  tags = merge(
    local.tags,
    var.kubernetes_subnet_tags,
    each.value.tags,
    {
      Name = lookup(each.value, "name", "") != "" ? "${each.value.name}" : "${local.name}-${var.kubernetes_subnet_suffix}-${each.value.az}"
      security_posture = "private"
    },
  )
}

################################################################################
# ElastiCache subnet
################################################################################

resource "aws_subnet" "elasticache" {
  for_each = length(var.elasticache_subnets) > 0 ? var.elasticache_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]
  assign_ipv6_address_on_creation = var.elasticache_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.elasticache_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.elasticache_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.elasticache_subnet_ipv6_prefixes[index(var.private_subnets, each.key)]) : null

  tags = merge(
    local.tags,
    var.elasticache_subnet_tags,
    each.value.tags,
    {
      Name = lookup(each.value, "name", "") != "" ? "${each.value.name}" : "${local.name}-${var.elasticache_subnet_suffix}-${each.value.az}"
      security_posture = "private"
    },
  )
}

resource "aws_elasticache_subnet_group" "elasticache" {
  count = length(var.elasticache_subnets) > 0 && var.create_elasticache_subnet_group ? 1 : 0

  name        = coalesce(var.elasticache_subnet_group_name, local.name)
  description = "ElastiCache subnet group for ${local.name}"
  subnet_ids  = [ for subnet in aws_subnet.elasticache : subnet.id ]

  tags = merge(
    local.tags,
    var.elasticache_subnet_group_tags,
    { "Name" = coalesce(var.elasticache_subnet_group_name, local.name) },
  )
}

################################################################################
# Isolated subnets - private subnet without NAT gateway
################################################################################
resource "aws_subnet" "isolated" {
  for_each = length(var.isolated_subnets) > 0 ? var.isolated_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]
  assign_ipv6_address_on_creation = var.isolated_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.isolated_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.isolated_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, var.isolated_subnet_ipv6_prefixes[index(var.isolated_subnets, each.key)]) : null

  tags = merge(
    local.tags,
    var.isolated_subnet_tags,
    each.value.tags,
    {
      Name = lookup(each.value, "name", "") != "" ? "${each.value.name}" : "${local.name}-${var.isolated_subnet_suffix}-${each.value.az}"
      security_posture = "private"
    },
  )
}

################################################################################
# Transit Gateway subnet
################################################################################
resource "aws_subnet" "transit_gateway_attachment" {
  for_each = length(var.transit_gateway_attachment_subnets) > 0 ? var.transit_gateway_attachment_subnets : {}

  vpc_id                          = local.vpc_id
  cidr_block                      = each.value.cidr_block
  availability_zone               = local.convert_az_to_zone_name[each.value.az]

  tags = merge(
    local.tags,
    each.value.tags,
    {
      Name = lookup(each.value, "name", "") != "" ? "${each.value.name}" : "${local.name}-tgw-attach-${each.value.az}"
      security_posture = "private"
    },
  )
}


################################################################################
# Default Network ACLs
################################################################################

resource "aws_default_network_acl" "this" {
  count = var.manage_default_network_acl ? 1 : 0

  default_network_acl_id = aws_vpc.this.default_network_acl_id

  # subnet_ids is using lifecycle ignore_changes, so it is not necessary to list
  # any explicitly. See https://github.com/terraform-aws-modules/terraform-aws-vpc/issues/736.
  subnet_ids = null

  dynamic "ingress" {
    for_each = var.default_network_acl_ingress
    content {
      action          = ingress.value.action
      cidr_block      = lookup(ingress.value, "cidr_block", null)
      from_port       = ingress.value.from_port
      icmp_code       = lookup(ingress.value, "icmp_code", null)
      icmp_type       = lookup(ingress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(ingress.value, "ipv6_cidr_block", null)
      protocol        = ingress.value.protocol
      rule_no         = ingress.value.rule_no
      to_port         = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.default_network_acl_egress
    content {
      action          = egress.value.action
      cidr_block      = lookup(egress.value, "cidr_block", null)
      from_port       = egress.value.from_port
      icmp_code       = lookup(egress.value, "icmp_code", null)
      icmp_type       = lookup(egress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(egress.value, "ipv6_cidr_block", null)
      protocol        = egress.value.protocol
      rule_no         = egress.value.rule_no
      to_port         = egress.value.to_port
    }
  }

  tags = merge(
    { "Name" = coalesce(var.default_network_acl_name, local.name) },
    local.tags,
    var.default_network_acl_tags,
  )

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

################################################################################
# Public Network ACLs
################################################################################

resource "aws_network_acl" "public" {
  count = var.public_dedicated_network_acl && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = [ for subnet in aws_subnet.public : subnet.id ]

  tags = merge(
    { "Name" = "${local.name}-${var.public_subnet_suffix}" },
    local.tags,
    var.public_acl_tags,
  )
}

resource "aws_network_acl_rule" "public_inbound" {
  count = var.public_dedicated_network_acl && length(var.public_subnets) > 0 ? length(var.public_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.public[0].id

  egress          = false
  rule_number     = var.public_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.public_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.public_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.public_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.public_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.public_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.public_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.public_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.public_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "public_outbound" {
  count = var.public_dedicated_network_acl && length(var.public_subnets) > 0 ? length(var.public_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.public[0].id

  egress          = true
  rule_number     = var.public_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.public_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.public_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.public_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.public_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.public_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.public_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.public_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.public_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# Private Network ACLs
################################################################################

resource "aws_network_acl" "private" {
  count = var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = [ for subnet in aws_subnet.private : subnet.id ]

  tags = merge(
    { "Name" = "${local.name}-${var.private_subnet_suffix}" },
    local.tags,
    var.private_acl_tags,
  )
}

resource "aws_network_acl_rule" "private_inbound" {
  count = var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? length(var.private_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress          = false
  rule_number     = var.private_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.private_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.private_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.private_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.private_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.private_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "private_outbound" {
  count = var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? length(var.private_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress          = true
  rule_number     = var.private_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.private_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.private_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.private_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.private_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.private_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# Isolated Network ACLs
################################################################################

resource "aws_network_acl" "isolated" {
  count = var.isolated_dedicated_network_acl && length(var.isolated_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = [ for subnet in aws_subnet.isolated : subnet.id ]

  tags = merge(
    { "Name" = "${var.isolated_subnet_suffix}-${local.name}" },
    local.tags,
    var.isolated_acl_tags,
  )
}

resource "aws_network_acl_rule" "isolated_inbound" {
  count = var.isolated_dedicated_network_acl && length(var.isolated_subnets) > 0 ? length(var.isolated_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.isolated[0].id

  egress          = false
  rule_number     = var.isolated_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.isolated_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.isolated_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.isolated_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.isolated_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.isolated_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.isolated_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.isolated_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.isolated_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "isolated_outbound" {
  count = var.isolated_dedicated_network_acl && length(var.isolated_subnets) > 0 ? length(var.isolated_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.isolated[0].id

  egress          = true
  rule_number     = var.isolated_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.isolated_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.isolated_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.isolated_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.isolated_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.isolated_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.isolated_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.isolated_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.isolated_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# Database Network ACLs
################################################################################

resource "aws_network_acl" "database" {
  count = var.database_dedicated_network_acl && length(var.database_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    local.tags,
    var.database_acl_tags,
    { "Name" = "${local.name}-${var.database_subnet_suffix}" },
  )
}

resource "aws_network_acl_rule" "database_inbound" {
  count = var.database_dedicated_network_acl && length(var.database_subnets) > 0 ? length(var.database_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.database[0].id

  egress          = false
  rule_number     = var.database_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.database_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.database_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.database_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.database_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.database_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.database_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.database_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.database_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "database_outbound" {
  count = var.database_dedicated_network_acl && length(var.database_subnets) > 0 ? length(var.database_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.database[0].id

  egress          = true
  rule_number     = var.database_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.database_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.database_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.database_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.database_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.database_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.database_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.database_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.database_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# Kubernetes Network ACLs
################################################################################

resource "aws_network_acl" "kubernetes" {
  count = var.kubernetes_dedicated_network_acl && length(var.kubernetes_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.kubernetes[*].id

  tags = merge(
    local.tags,
    var.kubernetes_acl_tags,
    { "Name" = "${local.name}-${var.kubernetes_subnet_suffix}" },
  )
}

resource "aws_network_acl_rule" "kubernetes_inbound" {
  count = var.kubernetes_dedicated_network_acl && length(var.kubernetes_subnets) > 0 ? length(var.kubernetes_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.kubernetes[0].id

  egress          = false
  rule_number     = var.kubernetes_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.kubernetes_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.kubernetes_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.kubernetes_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.kubernetes_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.kubernetes_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.kubernetes_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.kubernetes_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.kubernetes_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "kubernetes_outbound" {
  count = var.kubernetes_dedicated_network_acl && length(var.kubernetes_subnets) > 0 ? length(var.kubernetes_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.database[0].id

  egress          = true
  rule_number     = var.kubernetes_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.kubernetes_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.kubernetes_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.kubernetes_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.kubernetes_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.kubernetes_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.kubernetes_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.kubernetes_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.kubernetes_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# Elasticache Network ACLs
################################################################################

resource "aws_network_acl" "elasticache" {
  count = var.elasticache_dedicated_network_acl && length(var.elasticache_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.elasticache[*].id

  tags = merge(
    local.tags,
    var.elasticache_acl_tags,
    { "Name" = "${local.name}-${var.elasticache_subnet_suffix}" },
  )
}

resource "aws_network_acl_rule" "elasticache_inbound" {
  count = var.elasticache_dedicated_network_acl && length(var.elasticache_subnets) > 0 ? length(var.elasticache_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.elasticache[0].id

  egress          = false
  rule_number     = var.elasticache_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.elasticache_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.elasticache_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.elasticache_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.elasticache_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.elasticache_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.elasticache_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.elasticache_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.elasticache_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "elasticache_outbound" {
  count = var.elasticache_dedicated_network_acl && length(var.elasticache_subnets) > 0 ? length(var.elasticache_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.elasticache[0].id

  egress          = true
  rule_number     = var.elasticache_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.elasticache_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.elasticache_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.elasticache_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.elasticache_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.elasticache_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.elasticache_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.elasticache_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.elasticache_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# NAT Gateway
################################################################################
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway && !(var.reuse_nat_ips) ? local.nat_gateway_count : 0

  domain = "vpc"

  tags = merge(
    local.tags,
    var.nat_eip_tags,
    {
      "Name" = format(
        "${local.name}-%s",
        element(var.azs, !(var.one_nat_gateway_per_az) ? 0 : count.index),
      )
    },
  )
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = element(
    local.nat_gateway_ips,
    var.one_nat_gateway_per_az ? count.index : 0,
  )

  subnet_id = local.availability_zone_public_subnets[var.azs[count.index]][0]

  tags = merge(
    {
      "Name" = format(
        "${local.name}-%s",
        element(var.azs, !(var.one_nat_gateway_per_az) ? 0 : count.index),
      )
    },
    local.tags,
    var.nat_gateway_tags,
  )

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Route table association
################################################################################

resource "aws_route_table_association" "private" {
  for_each = length(var.private_subnets) > 0 ? var.private_subnets : {}

  subnet_id = aws_subnet.private[each.key].id
  #Private is the only one with a route table per subnet.
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "database" {
  for_each = var.create_database_subnet_route_table && length(var.database_subnets) > 0 ? var.database_subnets : {}

  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database[0].id
}

resource "aws_route_table_association" "elasticache" {
  for_each = var.create_elasticache_subnet_route_table && length(var.elasticache_subnets) > 0 ? var.elasticache_subnets : {}

  subnet_id = aws_subnet.elasticache[each.key].id
  route_table_id = aws_route_table.elasticache[0].id
}

resource "aws_route_table_association" "isolated" {
  for_each = length(var.isolated_subnets) > 0 ? var.isolated_subnets : {}

  subnet_id      = aws_subnet.isolated[each.key].id
  route_table_id = aws_route_table.isolated[each.key].id
}

resource "aws_route_table_association" "public" {
  for_each = length(var.public_subnets) > 0 ? var.public_subnets : {}

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}
