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
