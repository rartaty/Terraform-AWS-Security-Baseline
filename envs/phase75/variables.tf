variable "account_id" {
  type        = string
  description = "Expected AWS account; supply privately."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Supply one 12-digit account ID."
  }
}

variable "vpc_id" {
  type        = string
  description = "Existing Phase 7 learning VPC; this root never owns the VPC."
  validation {
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id))
    error_message = "Supply the existing learning VPC ID."
  }
}

variable "availability_zone" {
  type        = string
  description = "One available Tokyo AZ, checked against actual capacity before apply."
  validation {
    condition     = can(regex("^ap-northeast-1[a-z]$", var.availability_zone))
    error_message = "Use one standard Tokyo availability zone."
  }
}

variable "ami_id" {
  type        = string
  description = "Pinned Amazon-owned AL2023 x86_64 AMI matching the Lab IAM permissions."
  validation {
    condition     = can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "Supply the pinned AMI ID."
  }
}

variable "ebs_key_arn" {
  type        = string
  description = "Confirmed aws/ebs key ARN matching the Lab IAM permissions; not the audit log key."
  validation {
    condition     = can(regex("^arn:aws:kms:ap-northeast-1:${var.account_id}:key/[0-9a-f-]{36}$", var.ebs_key_arn))
    error_message = "Supply one EBS key ARN in the expected account and Tokyo."
  }
}

variable "rule_action" {
  type        = string
  default     = "alert"
  description = "Start with alert; change only to drop after matching the ALERT evidence."
  validation {
    condition     = contains(["alert", "drop"], var.rule_action)
    error_message = "Only alert and drop are permitted."
  }
}
