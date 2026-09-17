// This step creates the Route Table boundaries and makes their associations
// explicit.  Both tables initially contain only AWS's implicit local route.
// Internet Gateway and 0.0.0.0/0 routes are deliberately introduced later.
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
// No route other than the VPC-local route exists at this point.
resource "aws_route_table_association" "phase7" {
  for_each = local.phase7_subnet_route_table_tier

  subnet_id      = aws_subnet.phase7[each.key].id
  route_table_id = aws_route_table.phase7[each.value].id
}
