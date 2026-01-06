output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(aws_vpc.this.id, "")
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = try(aws_vpc.this.arn, "")
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(aws_vpc.this.cidr_block, "")
}

output "default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation"
  value       = try(aws_vpc.this.default_security_group_id, "")
}

output "default_network_acl_id" {
  description = "The ID of the default network ACL"
  value       = try(aws_vpc.this.default_network_acl_id, "")
}

output "default_route_table_id" {
  description = "The ID of the default route table"
  value       = try(aws_vpc.this.default_route_table_id, "")
}

output "kubernetes_subnets" {
  description = "List of IDs of kubernetes subnets"
  value       = [ for subnet in aws_subnet.kubernetes : subnet.id ]
}

output "kubernetes_subnet_arns" {
  description = "List of ARNs of kubernetes subnets"
  value       = [ for subnet in aws_subnet.kubernetes : subnet.arn ]
}

output "kubernetes_subnets_cidr_blocks" {
  description = "List of cidr_blocks of kubernetes subnets"
  value       = [ for subnet in aws_subnet.kubernetes : subnet.cidr_block ]
}

output "kubernetes_subnets_ipv6_cidr_blocks" {
  description = "List of IPv6 cidr_blocks of kubernetes subnets in an IPv6 enabled VPC"
  value       = [ for subnet in aws_subnet.kubernetes : subnet.ipv6_cidr_block ]
}

output "vpc_instance_tenancy" {
  description = "Tenancy of instances spin up within VPC"
  value       = try(aws_vpc.this.instance_tenancy, "")
}

output "vpc_enable_dns_support" {
  description = "Whether or not the VPC has DNS support"
  value       = try(aws_vpc.this.enable_dns_support, "")
}

output "vpc_enable_dns_hostnames" {
  description = "Whether or not the VPC has DNS hostname support"
  value       = try(aws_vpc.this.enable_dns_hostnames, "")
}

output "vpc_main_route_table_id" {
  description = "The ID of the main route table associated with this VPC"
  value       = try(aws_vpc.this.main_route_table_id, "")
}

output "vpc_ipv6_association_id" {
  description = "The association ID for the IPv6 CIDR block"
  value       = try(aws_vpc.this.ipv6_association_id, "")
}

output "vpc_ipv6_cidr_block" {
  description = "The IPv6 CIDR block"
  value       = try(aws_vpc.this.ipv6_cidr_block, "")
}

output "vpc_secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks of the VPC"
  value       = compact(aws_vpc_ipv4_cidr_block_association.this[*].cidr_block)
}

output "vpc_owner_id" {
  description = "The ID of the AWS account that owns the VPC"
  value       = try(aws_vpc.this.owner_id, "")
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = [ for subnet in aws_subnet.private : subnet.id ]
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = [ for subnet in aws_subnet.private : subnet.arn ]
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = [ for subnet in aws_subnet.private : subnet.cidr_block ]
}

output "private_subnets_ipv6_cidr_blocks" {
  description = "List of IPv6 cidr_blocks of private subnets in an IPv6 enabled VPC"
  value       = [ for subnet in aws_subnet.private : subnet.ipv6_cidr_block ]
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value = [ for subnet in aws_subnet.public : subnet.id ]
}

output "transit_gateway_attachment_subnets" {
  description = "List of IDs of transit gateway attachment subnets"
  value       = [ for subnet in aws_subnet.transit_gateway_attachment : subnet.id ]
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = [ for subnet in aws_subnet.public : subnet.arn ]
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = compact([ for subnet in aws_subnet.public : subnet.cidr_block ])
}

output "public_subnets_ipv6_cidr_blocks" {
  description = "List of IPv6 cidr_blocks of public subnets in an IPv6 enabled VPC"
  value       = compact([ for subnet in aws_subnet.public : subnet.ipv6_cidr_block ])
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = [ for subnet in aws_subnet.database : subnet.id ]
}

output "database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = [ for subnet in aws_subnet.database : subnet.arn ]
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = compact([ for subnet in aws_subnet.database : subnet.cidr_block ])
}

output "database_subnets_ipv6_cidr_blocks" {
  description = "List of IPv6 cidr_blocks of database subnets in an IPv6 enabled VPC"
  value       = compact([ for subnet in aws_subnet.database : subnet.ipv6_cidr_block ])

}

output "database_subnet_group" {
  description = "ID of database subnet group"
  value       = try(aws_db_subnet_group.database[0].id, "")
}

output "database_subnet_group_name" {
  description = "Name of database subnet group"
  value       = try(aws_db_subnet_group.database[0].name, "")
}

output "elasticache_subnets" {
  description = "List of IDs of elasticache subnets"
  value       = [ for subnet in aws_subnet.elasticache : subnet.id ]
}

output "elasticache_subnet_arns" {
  description = "List of ARNs of elasticache subnets"
  value       = [ for subnet in aws_subnet.elasticache : subnet.arn ]
}

output "elasticache_subnets_cidr_blocks" {
  description = "List of cidr_blocks of elasticache subnets"
  value       = compact([ for subnet in aws_subnet.elasticache : subnet.cidr_block ])
}

output "elasticache_subnets_ipv6_cidr_blocks" {
  description = "List of IPv6 cidr_blocks of elasticache subnets in an IPv6 enabled VPC"
  value       = compact([ for subnet in aws_subnet.elasticache : subnet.ipv6_cidr_block ])
}

output "isolated_subnets" {
  description = "List of IDs of isolated subnets"
  value       = [ for subnet in aws_subnet.isolated : subnet.id ]
}

output "isolated_subnet_arns" {
  description = "List of ARNs of isolated subnets"
  value       = [ for subnet in aws_subnet.isolated : subnet.arn ]
}

output "isolated_subnets_cidr_blocks" {
  description = "List of cidr_blocks of isolated subnets"
  value       = compact([ for subnet in aws_subnet.isolated : subnet.cidr_block ])
}

output "isolated_subnets_ipv6_cidr_blocks" {
  description = "List of IPv6 cidr_blocks of isolated subnets in an IPv6 enabled VPC"
  value       = compact([ for subnet in aws_subnet.isolated : subnet.ipv6_cidr_block ])
}

output "elasticache_subnet_group" {
  description = "ID of elasticache subnet group"
  value       = try(aws_elasticache_subnet_group.elasticache[0].id, "")
}

output "elasticache_subnet_group_name" {
  description = "Name of elasticache subnet group"
  value       = try(aws_elasticache_subnet_group.elasticache[0].name, "")
}

output "public_route_table_ids" {
  description = "List of IDs of public route tables"
  value       = [ for table in aws_route_table.public : table.id ]
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = [ for table in aws_route_table.private : table.id ]
}

output "database_route_table_ids" {
  description = "List of IDs of database route tables"
  value       = try(coalescelist([ for table in aws_route_table.database : table.id ], [ for table in aws_route_table.private : table.id ]), [])
}

output "elasticache_route_table_ids" {
  description = "List of IDs of elasticache route tables"
  value       = try(coalescelist([ for table in aws_route_table.elasticache : table.id ], [ for table in aws_route_table.private : table.id ]), [])
}

output "isolated_route_table_ids" {
  description = "List of IDs of isolated route tables"
  value = [ for table in aws_route_table.isolated : table.id ]
}

output "public_internet_gateway_route_id" {
  description = "ID of the internet gateway route"
  value       = try(aws_route.public_internet_gateway[0].id, "")
}

output "public_internet_gateway_ipv6_route_id" {
  description = "ID of the IPv6 internet gateway route"
  value       = try(aws_route.public_internet_gateway_ipv6[0].id, "")
}

output "database_internet_gateway_route_id" {
  description = "ID of the database internet gateway route"
  value       = try(aws_route.database_internet_gateway[0].id, "")
}

output "database_nat_gateway_route_ids" {
  description = "List of IDs of the database nat gateway route"
  value       = [ for route in aws_route.database_nat_gateway : route.id ]
}

output "database_ipv6_egress_route_id" {
  description = "ID of the database IPv6 egress route"
  value       = try(aws_route.database_ipv6_egress[0].id, "")
}

output "private_nat_gateway_route_ids" {
  description = "List of IDs of the private nat gateway route"
  value       = [ for route in aws_route.private_nat_gateway : route.id ]
}

output "private_ipv6_egress_route_ids" {
  description = "List of IDs of the ipv6 egress route"
  value       = [ for route in aws_route.private_ipv6_egress : route.id ]
}

output "private_route_table_association_ids" {
  description = "List of IDs of the private route table association"
  value       = [ for a in aws_route_table_association.private : a.id ]
}

output "database_route_table_association_ids" {
  description = "List of IDs of the database route table association"
  value       = [ for a in aws_route_table_association.database : a.id ]
}

output "elasticache_route_table_association_ids" {
  description = "List of IDs of the elasticache route table association"
  value       = [ for a in aws_route_table_association.elasticache : a.id ]
}

output "isolated_route_table_association_ids" {
  description = "List of IDs of the isolated route table association"
  value       = [ for a in aws_route_table_association.isolated : a.id ]
}

output "public_route_table_association_ids" {
  description = "List of IDs of the public route table association"
  value       = [ for a in aws_route_table_association.public : a.id ]
}

output "dhcp_options_id" {
  description = "The ID of the DHCP options"
  value       = try(aws_vpc_dhcp_options.this[0].id, "")
}

output "nat_ids" {
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway"
  value       = aws_eip.nat[*].id
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = var.reuse_nat_ips ? var.external_nat_ips : aws_eip.nat[*].public_ip
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = try(aws_internet_gateway.this[0].id, "")
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway"
  value       = try(aws_internet_gateway.this[0].arn, "")
}

output "egress_only_internet_gateway_id" {
  description = "The ID of the egress only Internet Gateway"
  value       = try(aws_egress_only_internet_gateway.this[0].id, "")
}



output "public_network_acl_id" {
  description = "ID of the public network ACL"
  value       = try(aws_network_acl.public[0].id, "")
}

output "public_network_acl_arn" {
  description = "ARN of the public network ACL"
  value       = try(aws_network_acl.public[0].arn, "")
}

output "private_network_acl_id" {
  description = "ID of the private network ACL"
  value       = try(aws_network_acl.private[0].id, "")
}

output "private_network_acl_arn" {
  description = "ARN of the private network ACL"
  value       = try(aws_network_acl.private[0].arn, "")
}

output "isolated_network_acl_id" {
  description = "ID of the isolated network ACL"
  value       = try(aws_network_acl.isolated[0].id, "")
}

output "isolated_network_acl_arn" {
  description = "ARN of the isolated network ACL"
  value       = try(aws_network_acl.isolated[0].arn, "")
}

output "database_network_acl_id" {
  description = "ID of the database network ACL"
  value       = try(aws_network_acl.database[0].id, "")
}

output "database_network_acl_arn" {
  description = "ARN of the database network ACL"
  value       = try(aws_network_acl.database[0].arn, "")
}

output "elasticache_network_acl_id" {
  description = "ID of the elasticache network ACL"
  value       = try(aws_network_acl.elasticache[0].id, "")
}

output "elasticache_network_acl_arn" {
  description = "ARN of the elasticache network ACL"
  value       = try(aws_network_acl.elasticache[0].arn, "")
}

# VPC flow log
output "vpc_flow_log_id" {
  description = "The ID of the Flow Log resource"
  value       = try(aws_flow_log.this[0].id, "")
}

output "vpc_flow_log_destination_arn" {
  description = "The ARN of the destination for VPC Flow Logs"
  value       = local.flow_log_destination_arn
}

output "vpc_flow_log_destination_type" {
  description = "The type of the destination for VPC Flow Logs"
  value       = var.flow_log_destination_type
}

output "vpc_flow_log_cloudwatch_iam_role_arn" {
  description = "The ARN of the IAM role used when pushing logs to Cloudwatch log group"
  value       = local.flow_log_iam_role_arn
}

# Static values (arguments)
output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = var.azs
}

output "name" {
  description = "The name of the VPC specified as argument to this module"
  value       = var.name
}
