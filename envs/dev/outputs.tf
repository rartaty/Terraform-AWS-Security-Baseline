output "aws_account_id" {
  description = "AWS account ID currently authenticated"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by the provider"
  value       = data.aws_region.current.region
}
