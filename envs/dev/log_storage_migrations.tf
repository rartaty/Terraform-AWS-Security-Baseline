// Keep policy ARNs stable while the empty buckets exit before the reader Roles.
locals {
  log_bucket_arns = {
    cloudtrail = "arn:aws:s3:::${var.cloudtrail_bucket_name}"
    config     = "arn:aws:s3:::${var.config_bucket_name}"
    flow_logs  = "arn:aws:s3:::${var.flow_logs_bucket_name}"
  }
}

moved {
  from = aws_s3_bucket.cloudtrail_logs
  to   = aws_s3_bucket.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket_ownership_controls.cloudtrail_logs
  to   = aws_s3_bucket_ownership_controls.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket_public_access_block.cloudtrail_logs
  to   = aws_s3_bucket_public_access_block.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.cloudtrail_logs
  to   = aws_s3_bucket_server_side_encryption_configuration.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket_versioning.cloudtrail_logs
  to   = aws_s3_bucket_versioning.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.cloudtrail_logs
  to   = aws_s3_bucket_lifecycle_configuration.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket_policy.cloudtrail_logs
  to   = aws_s3_bucket_policy.cloudtrail_logs[0]
}
moved {
  from = aws_s3_bucket.config_history
  to   = aws_s3_bucket.config_history[0]
}
moved {
  from = aws_s3_bucket_ownership_controls.config_history
  to   = aws_s3_bucket_ownership_controls.config_history[0]
}
moved {
  from = aws_s3_bucket_public_access_block.config_history
  to   = aws_s3_bucket_public_access_block.config_history[0]
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.config_history
  to   = aws_s3_bucket_server_side_encryption_configuration.config_history[0]
}
moved {
  from = aws_s3_bucket_versioning.config_history
  to   = aws_s3_bucket_versioning.config_history[0]
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.config_history
  to   = aws_s3_bucket_lifecycle_configuration.config_history[0]
}
moved {
  from = aws_s3_bucket_policy.config_history
  to   = aws_s3_bucket_policy.config_history[0]
}
moved {
  from = aws_s3_bucket.flow_logs
  to   = aws_s3_bucket.flow_logs[0]
}
moved {
  from = aws_s3_bucket_ownership_controls.flow_logs
  to   = aws_s3_bucket_ownership_controls.flow_logs[0]
}
moved {
  from = aws_s3_bucket_public_access_block.flow_logs
  to   = aws_s3_bucket_public_access_block.flow_logs[0]
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.flow_logs
  to   = aws_s3_bucket_server_side_encryption_configuration.flow_logs[0]
}
moved {
  from = aws_s3_bucket_versioning.flow_logs
  to   = aws_s3_bucket_versioning.flow_logs[0]
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.flow_logs
  to   = aws_s3_bucket_lifecycle_configuration.flow_logs[0]
}
moved {
  from = aws_s3_bucket_policy.flow_logs
  to   = aws_s3_bucket_policy.flow_logs[0]
}
