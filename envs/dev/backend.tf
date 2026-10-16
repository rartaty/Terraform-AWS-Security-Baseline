terraform {
  # Final teardown can use the ignored phase8_backend_override.tf to migrate
  # state locally. This public definition remains the normal S3 backend.
  backend "s3" {
    bucket       = "replace-with-existing-state-bucket-name"
    key          = "envs/dev/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
    profile      = "terraform"
  }
}
