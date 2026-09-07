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
