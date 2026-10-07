terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key                  = "labs/phase75/terraform.tfstate"
    workspace_key_prefix = "labs/phase75/workspaces"
    region               = "ap-northeast-1"
    encrypt              = true
    use_lockfile         = true
    profile              = "phase75-lab"
  }
}
