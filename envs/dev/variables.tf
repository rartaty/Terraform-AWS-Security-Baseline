variable "aws_region" {
  description = "AWS resources deployment region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tags"
  type        = string
  default     = "terraform-aws-security-baseline"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be dev, stg, or prod."
  }
}

variable "budget_notification_email" {
  description = "Email address that receives AWS Budget alerts"
  type        = string
  sensitive   = true
}

variable "cloudtrail_bucket_name" {
  description = "Globally unique S3 bucket name for CloudTrail logs"
  type        = string
}

variable "config_bucket_name" {
  description = "Globally unique S3 bucket name for AWS Config configuration history"
  type        = string
}
variable "flow_logs_bucket_name" {
  description = "Globally unique S3 bucket name for Phase 7 VPC Flow Logs"
  type        = string
}
variable "enable_phase7_test" {
  description = "Enable temporary Phase 7 network test resources"
  type        = bool
  default     = false
}
variable "enable_phase7_config_audit" {
  description = "Enable the temporary role for Config history verification"
  type        = bool
  default     = false
}

variable "phase7_config_audit_object_key" {
  description = "Exact S3 object key of the Config history file to verify"
  type        = string
  default     = ""
}

variable "cloudtrail_reader_boundary_arn" {
  description = "Root-managed CloudTrail reader boundary ARN; null until the staged IAM migration"
  type        = string
  default     = null
}

variable "config_reader_boundary_arn" {
  description = "Root-managed Config reader boundary ARN; null until the staged IAM migration"
  type        = string
  default     = null
}

variable "enable_baseline_monitoring" {
  description = "Create detection services, AWS Config, and VPC Flow Logs; disable during staged teardown"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Create the audit trail; disable only after reviewing evidence preservation during staged teardown"
  type        = bool
  default     = true
}

variable "enable_phase7_network" {
  description = "Create the learning network; disable during staged teardown after stopping monitoring and test workloads"
  type        = bool
  default     = true
}

variable "enable_log_storage" {
  description = "Create the three log buckets; disable only after sources have stopped and all versions are removed"
  type        = bool
  default     = true
}

variable "kms_retirement_role_arn" {
  description = "Optional one-key retirement role; configure only during reviewed staged teardown"
  type        = string
  default     = null

  validation {
    condition     = var.kms_retirement_role_arn == null ? true : can(regex("^arn:aws:iam::[0-9]{12}:role/TemporaryPhase8KmsRetirementRole$", var.kms_retirement_role_arn))
    error_message = "Use the designated temporary retirement role ARN."
  }
}

variable "kms_retirement_expires_at" {
  description = "UTC expiry for the optional retirement key-policy grant"
  type        = string
  default     = null

  validation {
    condition     = var.kms_retirement_expires_at == null ? true : can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", var.kms_retirement_expires_at)) && can(timecmp(var.kms_retirement_expires_at, var.kms_retirement_expires_at))
    error_message = "Provide an RFC3339 UTC timestamp ending in Z."
  }
}

variable "kms_use_retirement_role" {
  description = "Use the restricted temporary role for the KMS-only provider during reviewed retirement"
  type        = bool
  default     = false
}

variable "enable_security_logs_key" {
  description = "Manage the security-log key; disable only after reviewing the one-key retirement plan"
  type        = bool
  default     = true
}

variable "enable_evidence_readers" {
  description = "Manage the two evidence-reader roles; disable after evidence preservation and key retirement"
  type        = bool
  default     = true
}

variable "enable_budget" {
  description = "Manage the project budget, notifications and action; disable only in the final teardown stage"
  type        = bool
  default     = true
}

variable "retired_security_logs_key_arn" {
  description = "Exact retiring key ARN retained for unchanged IAM deny references after key management ends"
  type        = string
  default     = null

  validation {
    condition     = var.retired_security_logs_key_arn == null ? true : can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]{36}$", var.retired_security_logs_key_arn))
    error_message = "Provide one exact symmetric KMS key ARN without wildcards."
  }
}
