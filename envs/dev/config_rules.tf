locals {
  config_managed_rules = {
    s3_account_public_access = {
      name                        = "s3-account-bpa"
      description                 = "Checks account-level S3 Block Public Access settings."
      source_identifier           = "S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS"
      maximum_execution_frequency = null
    }

    s3_public_read = {
      name                        = "s3-public-read"
      description                 = "Checks whether S3 buckets prohibit public read access."
      source_identifier           = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      maximum_execution_frequency = "TwentyFour_Hours"
    }

    s3_public_write = {
      name                        = "s3-public-write"
      description                 = "Checks whether S3 buckets prohibit public write access."
      source_identifier           = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
      maximum_execution_frequency = "TwentyFour_Hours"
    }

    s3_encryption = {
      name                        = "s3-encryption"
      description                 = "Checks whether S3 buckets have server-side encryption enabled."
      source_identifier           = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
      maximum_execution_frequency = null
    }

    cloudtrail_multi_region = {
      name                        = "cloudtrail-multi-region"
      description                 = "Checks whether a multi-region CloudTrail records management events."
      source_identifier           = "MULTI_REGION_CLOUD_TRAIL_ENABLED"
      maximum_execution_frequency = "TwentyFour_Hours"
    }

    cloudtrail_encryption = {
      name                        = "cloudtrail-encryption"
      description                 = "Checks whether CloudTrail uses KMS encryption."
      source_identifier           = "CLOUD_TRAIL_ENCRYPTION_ENABLED"
      maximum_execution_frequency = "TwentyFour_Hours"
    }

    cloudtrail_validation = {
      name                        = "cloudtrail-validation"
      description                 = "Checks whether CloudTrail log file validation is enabled."
      source_identifier           = "CLOUD_TRAIL_LOG_FILE_VALIDATION_ENABLED"
      maximum_execution_frequency = "TwentyFour_Hours"
    }
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_managed_rules

  name                        = "${var.project_name}-${var.environment}-${each.value.name}"
  description                 = each.value.description
  maximum_execution_frequency = each.value.maximum_execution_frequency

  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier
  }

  evaluation_mode {
    mode = "DETECTIVE"
  }

  depends_on = [
    aws_config_configuration_recorder_status.security_baseline
  ]
}