locals {
  phase7_subnets = {
    public_a = {
      cidr_block        = "10.70.0.0/24"
      availability_zone = "ap-northeast-1a"
      network_tier      = "public"
    }
    public_b = {
      cidr_block        = "10.70.1.0/24"
      availability_zone = "ap-northeast-1c"
      network_tier      = "public"
    }
    isolated_a = {
      cidr_block        = "10.70.10.0/24"
      availability_zone = "ap-northeast-1a"
      network_tier      = "isolated"
    }
    isolated_b = {
      cidr_block        = "10.70.11.0/24"
      availability_zone = "ap-northeast-1c"
      network_tier      = "isolated"
    }
  }
}

// A subnet allocates an address range within the learning VPC. It has no
// Internet route on its own. Route tables and associations are in network_routes.tf.
resource "aws_subnet" "phase7" {
  for_each = local.phase7_subnets

  vpc_id                  = aws_vpc.phase7_learning.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-phase7-${replace(each.key, "_", "-")}"
    Purpose     = "phase7-network-learning"
    NetworkTier = each.value.network_tier
  }
}
