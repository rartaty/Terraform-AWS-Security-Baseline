// Both Route Tables retain the implicit VPC-local route. Only the public
// table receives the Internet Gateway default route defined below.
locals {
  phase7_route_table_tiers = toset(["public", "isolated"])

  phase7_subnet_route_table_tier = {
    public_a   = "public"
    public_b   = "public"
    isolated_a = "isolated"
    isolated_b = "isolated"
  }
}

resource "aws_route_table" "phase7" {
  for_each = local.phase7_route_table_tiers

  vpc_id = aws_vpc.phase7_learning.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-phase7-${each.key}-route"
    Purpose     = "phase7-network-learning"
    NetworkTier = each.key
  }
}

// An explicit association makes the intended routing boundary visible in code.
// Isolated subnets have no route outside the VPC.
resource "aws_route_table_association" "phase7" {
  for_each = local.phase7_subnet_route_table_tier

  subnet_id      = aws_subnet.phase7[each.key].id
  route_table_id = aws_route_table.phase7[each.value].id
}

resource "aws_internet_gateway" "phase7" {
  vpc_id = aws_vpc.phase7_learning.id

  tags = {
    Name    = "${var.project_name}-${var.environment}-phase7-igw"
    Purpose = "phase7-network-learning"
  }
}

resource "aws_route" "phase7_public_default" {
  route_table_id         = aws_route_table.phase7["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.phase7.id
}
