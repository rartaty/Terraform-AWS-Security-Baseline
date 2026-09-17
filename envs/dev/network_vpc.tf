// Phase 7 begins with the learning VPC only.  Subnets, routing, and security
// groups are deliberately added in a later step after their IAM permissions
// can be restricted to this VPC's concrete ID.
resource "aws_vpc" "phase7_learning" {
  cidr_block           = "10.70.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-${var.environment}-phase7-learning"
    Purpose = "phase7-network-learning"
  }
}

// AWS creates one default security group with every VPC.  Query it explicitly
// instead of relying on a computed aws_vpc attribute, which can be empty in
// provider state even when the group exists in AWS.
data "aws_security_group" "phase7_learning_default" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.phase7_learning.id]
  }

  filter {
    name   = "group-name"
    values = ["default"]
  }
}
