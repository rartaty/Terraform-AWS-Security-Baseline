provider "aws" {
  region              = "ap-northeast-1"
  profile             = "phase75-lab"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.common_tags
  }
}

locals {
  prefix = "terraform-aws-security-baseline-dev-phase75"
  common_tags = {
    Project     = "terraform-aws-security-baseline"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Purpose     = "phase75-firewall-test"
  }
  subnet_cidrs = {
    client     = "10.70.20.0/24"
    inspection = "10.70.21.0/24"
    server     = "10.70.22.0/24"
  }
  client_ip = cidrhost(local.subnet_cidrs.client, 10)
  server_ip = cidrhost(local.subnet_cidrs.server, 10)
}
