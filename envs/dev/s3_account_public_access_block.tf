# Keep account-wide S3 public access protection after this learning environment exits.
# This removes only Terraform ownership; the AWS setting remains enabled.
removed {
  from = aws_s3_account_public_access_block.this

  lifecycle {
    destroy = false
  }
}
