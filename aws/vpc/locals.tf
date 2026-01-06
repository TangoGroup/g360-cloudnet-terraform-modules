locals {
  name = length(var.name) > 0 ? "${var.name}" : "${var.project_name}-${var.project_env}"

  #Set the NAT Gateway count. enable_nat_gateway must be true.
  #Then, by default, there will be one NAT GW in the VPC.  If one_nat_gateway_per_az is true, then there will be one per zone.
  nat_gateway_count = var.enable_nat_gateway ? var.one_nat_gateway_per_az ? length(var.azs) : 1 : 0

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this.id, "")

  tags = merge(
    {
      project_name       = var.project_name
      project_env        = var.project_env
      owner              = "zz-wycliffe-it-systems-engineering-architecture-team-staff-usa@wycliffe.org"
      terraform_managed  = "true"
    },
    var.tags,
  )

  #Get a map of private subnets by the availability zones containing them.
  # Using availability_zone_id for consistency across accounts (zone IDs are stable, zone names vary)
  availability_zone_private_subnets = {
    for s in aws_subnet.private : s.availability_zone_id => s.id...
  }

  #Get a map of subnets by the availability zones containing them.
  # Using availability_zone_id for consistency across accounts (zone IDs are stable, zone names vary)
  availability_zone_public_subnets = {
    for s in aws_subnet.public : s.availability_zone_id => s.id...
  }

  #Get a map of NAT gateways by the subnets containing them.
  availability_zone_nat_gateways = {
    for n in aws_nat_gateway.this : n.subnet_id => n.id...
  }

  #Get a map of routes by the private subnets containing them.
  #Formatted as a flattend list due to complexities of gathering the data.
  # Supports routes as a map where keys are destination CIDR blocks
  private_subnets_routes_as_list = flatten([
    for sk, sv in var.private_subnets : [
      for dcidr, route in try(sv.routes, {}) : {
        source_cidr_block          = sk
        destination_cidr_block    = dcidr
        egress_only_gateway_id     = lookup(route, "egress_only_gateway_id", null)
        gateway_id                 = lookup(route, "gateway_id", null)
        nat_gateway_id             = lookup(route, "nat_gateway_id", null)
        network_interface_id       = lookup(route, "network_interface_id", null)
        transit_gateway_id         = lookup(route, "transit_gateway_id", null)
        vpc_endpoint_id            = lookup(route, "vpc_endpoint_id", null)
        vpc_peering_connection_id  = lookup(route, "vpc_peering_connection_id", null)
      }
    ] if try(length(sv.routes) > 0, false)
  ])
  private_subnets_routes = { #Format as a map
    for r in local.private_subnets_routes_as_list : "${r.source_cidr_block}_to_${r.destination_cidr_block}" => r
  }

  #Get a map of routes by the isolated subnets containing them.
  #Formatted as a flattend list due to complexities of gathering the data.
  # Supports routes as a map where keys are destination CIDR blocks
  isolated_subnets_routes_as_list = flatten([
    for sk, sv in var.isolated_subnets : [
      for dcidr, route in try(sv.routes, {}) : {
        source_cidr_block          = sk
        destination_cidr_block    = dcidr
        egress_only_gateway_id     = lookup(route, "egress_only_gateway_id", null)
        gateway_id                 = lookup(route, "gateway_id", null)
        nat_gateway_id             = lookup(route, "nat_gateway_id", null)
        network_interface_id       = lookup(route, "network_interface_id", null)
        transit_gateway_id         = lookup(route, "transit_gateway_id", null)
        vpc_endpoint_id            = lookup(route, "vpc_endpoint_id", null)
        vpc_peering_connection_id  = lookup(route, "vpc_peering_connection_id", null)
      }
    ] if try(length(sv.routes) > 0, false)
  ])
  isolated_subnets_routes = { #Format as a map
    for r in local.isolated_subnets_routes_as_list : "${r.source_cidr_block}_to_${r.destination_cidr_block}" => r
  }

  #Get external IPs for NAT Gateways.
  nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : try(aws_eip.nat[*].id, [])

  # Map availability zone IDs to zone names
  # Create a map of zone_id -> zone_name for lookup
  availability_zone_id_to_name = {
    for idx, zone_id in data.aws_availability_zones.available.zone_ids : zone_id => data.aws_availability_zones.available.names[idx]
  }

  # Create a comprehensive map that handles both zone IDs and zone names
  # Maps both zone IDs and zone names to zone names for easy lookup
  # This allows users to specify either format in their subnet configurations
  convert_az_to_zone_name = merge(
    # Map zone IDs to zone names
    local.availability_zone_id_to_name,
    # Map zone names to themselves (identity mapping)
    {
      for zone_name in data.aws_availability_zones.available.names : zone_name => zone_name
    }
  )
}