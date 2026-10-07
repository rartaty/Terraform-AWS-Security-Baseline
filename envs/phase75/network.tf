data "aws_vpc" "learning" {
  id = var.vpc_id
}

data "aws_availability_zone" "lab" {
  name = var.availability_zone
}

resource "aws_subnet" "lab" {
  for_each = local.subnet_cidrs

  vpc_id                  = data.aws_vpc.learning.id
  availability_zone       = data.aws_availability_zone.lab.name
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.prefix}-${each.key}" }

  lifecycle {
    precondition {
      condition = (
        terraform.workspace == "default" &&
        data.aws_vpc.learning.cidr_block == "10.70.0.0/16" &&
        lookup(data.aws_vpc.learning.tags, "Project", "") == local.common_tags.Project &&
        lookup(data.aws_vpc.learning.tags, "Purpose", "") == "phase7-network-learning"
      )
      error_message = "Use the default workspace and the existing Phase 7 learning VPC."
    }
  }
}

resource "aws_route_table" "lab" {
  for_each = local.subnet_cidrs

  vpc_id = data.aws_vpc.learning.id
  tags   = { Name = "${local.prefix}-${each.key}-route" }
}

resource "aws_route_table_association" "lab" {
  for_each = local.subnet_cidrs

  subnet_id      = aws_subnet.lab[each.key].id
  route_table_id = aws_route_table.lab[each.key].id
}

locals {
  endpoint_id = one(aws_networkfirewall_firewall.lab.firewall_status[0].sync_states).attachment[0].endpoint_id
}

resource "aws_route" "peer" {
  for_each = {
    client = local.subnet_cidrs.server
    server = local.subnet_cidrs.client
  }

  route_table_id         = aws_route_table.lab[each.key].id
  destination_cidr_block = each.value
  vpc_endpoint_id        = local.endpoint_id
}

resource "aws_security_group" "lab" {
  for_each = toset(["client", "server"])

  name        = "${local.prefix}-${each.key}"
  description = "Private HTTP only for the short-lived firewall lab"
  vpc_id      = data.aws_vpc.learning.id
  tags        = { Name = "${local.prefix}-${each.key}-sg" }
}

# Use IP rules, not SG references, because traffic crosses a middlebox.
resource "aws_vpc_security_group_egress_rule" "client" {
  security_group_id = aws_security_group.lab["client"].id
  cidr_ipv4         = "${local.server_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  tags              = { Name = "${local.prefix}-client-http" }
}

resource "aws_vpc_security_group_ingress_rule" "server" {
  security_group_id = aws_security_group.lab["server"].id
  cidr_ipv4         = "${local.client_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  tags              = { Name = "${local.prefix}-server-http" }
}
