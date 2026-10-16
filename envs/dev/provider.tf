provider "aws" {
  profile = "terraform"
  region  = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Only the security-log key uses this provider; backend and other resources keep
# the normal Terraform execution role. No persistent CLI profile is required.
provider "aws" {
  alias   = "kms_retirement"
  profile = var.kms_use_retirement_role ? "terraform-login-bridge" : "terraform"
  region  = var.aws_region

  dynamic "assume_role" {
    for_each = var.kms_use_retirement_role ? [var.kms_retirement_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "phase8-kms-retirement"
      duration     = "15m"
    }
  }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
