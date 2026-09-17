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
