terraform {
  backend "s3" {
    bucket       = "replace-with-existing-state-bucket-name"
    key          = "envs/dev/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
    profile      = "terraform"
  }
}
