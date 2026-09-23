output "aws_account_id" {
  description = "AWS account ID currently authenticated"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by the provider"
  value       = data.aws_region.current.region
}

output "phase7_learning_vpc_id" {
  description = "Learning VPC ID used to scope later Phase 7 IAM permissions"
  value       = aws_vpc.phase7_learning.id
}

output "phase7_learning_default_security_group_id" {
  description = "Default security group ID; hardened in the scoped follow-up step"
  value       = data.aws_security_group.phase7_learning_default.id
}

output "phase7_subnet_ids" {
  description = "Subnet IDs keyed by their Phase 7 network role"
  value       = { for key, subnet in aws_subnet.phase7 : key => subnet.id }
}
output "phase7_test_details" {
  description = "Temporary test resource identifiers for evidence collection"

  value = var.enable_phase7_test ? {
    client = {
      instance_id       = aws_instance.phase7_test_client[0].id
      private_ip        = aws_instance.phase7_test_client[0].private_ip
      eni_id            = aws_instance.phase7_test_client[0].primary_network_interface_id
      security_group_id = aws_security_group.phase7_test_client[0].id
    }

    server = {
      instance_id       = aws_instance.phase7_test_server[0].id
      private_ip        = aws_instance.phase7_test_server[0].private_ip
      eni_id            = aws_instance.phase7_test_server[0].primary_network_interface_id
      security_group_id = aws_security_group.phase7_test_server[0].id
    }
  } : null
}
