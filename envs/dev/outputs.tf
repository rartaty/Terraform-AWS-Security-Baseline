output "aws_account_id" {
  description = "AWS account ID currently authenticated"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by the provider"
  value       = data.aws_region.current.region

  precondition {
    condition     = var.enable_log_storage || (!var.enable_baseline_monitoring && !var.enable_cloudtrail && !var.enable_phase7_config_audit)
    error_message = "Stop log sources and Config audit tests before disabling log storage."
  }

  precondition {
    condition     = var.enable_security_logs_key || (!var.enable_log_storage && !var.enable_baseline_monitoring && !var.enable_cloudtrail && !var.enable_phase7_config_audit)
    error_message = "Remove key-dependent log storage, monitoring and audit tests before retiring the key."
  }
  precondition {
    condition     = var.enable_security_logs_key || var.retired_security_logs_key_arn != null
    error_message = "Retain the exact retiring key ARN for unchanged IAM policy references."
  }
  precondition {
    condition     = !var.kms_use_retirement_role || (var.kms_retirement_role_arn != null && var.kms_retirement_expires_at != null)
    error_message = "The KMS-only retirement provider requires the reviewed role ARN and expiry."
  }
  precondition {
    condition     = var.retired_security_logs_key_arn == null ? true : startswith(var.retired_security_logs_key_arn, "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/")
    error_message = "The retained key ARN must belong to the configured account and region."
  }
  precondition {
    condition     = var.enable_evidence_readers || (!var.enable_security_logs_key && !var.enable_log_storage && !var.enable_cloudtrail && !var.enable_phase7_config_audit)
    error_message = "Preserve evidence and retire key/log storage before removing the evidence-reader roles."
  }
  precondition {
    condition     = var.enable_budget || (!var.enable_baseline_monitoring && !var.enable_cloudtrail && !var.enable_phase7_network && !var.enable_log_storage && !var.enable_security_logs_key && !var.enable_evidence_readers && !var.enable_phase7_test && !var.enable_phase7_config_audit)
    error_message = "Remove baseline workloads and readers before retiring the project budget protection."
  }
}

output "phase7_learning_vpc_id" {
  description = "Learning VPC ID used to scope later Phase 7 IAM permissions"
  value       = var.enable_phase7_network ? aws_vpc.phase7_learning[0].id : null
}

output "phase7_learning_default_security_group_id" {
  description = "Default security group ID; hardened in the scoped follow-up step"
  value       = var.enable_phase7_network ? data.aws_security_group.phase7_learning_default[0].id : null
}

output "phase7_subnet_ids" {
  description = "Subnet IDs keyed by their Phase 7 network role"
  value       = { for key, subnet in aws_subnet.phase7 : key => subnet.id }

  precondition {
    condition     = var.enable_phase7_network || (!var.enable_baseline_monitoring && !var.enable_phase7_test)
    error_message = "Stop baseline monitoring and Phase 7 test workloads before disabling the learning network."
  }
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
