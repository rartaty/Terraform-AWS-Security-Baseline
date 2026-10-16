data "aws_iam_role" "config_service_linked" {
  count = var.enable_baseline_monitoring ? 1 : 0

  name = "AWSServiceRoleForConfig"
}

resource "aws_config_configuration_recorder" "security_baseline" {
  count = var.enable_baseline_monitoring ? 1 : 0

  name     = "${var.project_name}-${var.environment}-recorder"
  role_arn = data.aws_iam_role.config_service_linked[0].arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false

    resource_types = [
      "AWS::S3::Bucket",
      "AWS::S3::AccountPublicAccessBlock",
      "AWS::CloudTrail::Trail",
      "AWS::KMS::Key",
      "AWS::IAM::Role",
      "AWS::IAM::User",
      "AWS::IAM::Policy",
      "AWS::GuardDuty::Detector",
      "AWS::AccessAnalyzer::Analyzer",
      "AWS::Config::ResourceCompliance",
      "AWS::EC2::VPC",
      "AWS::EC2::Subnet",
      "AWS::EC2::RouteTable",
      "AWS::EC2::SecurityGroup",
      "AWS::EC2::InternetGateway",
      "AWS::EC2::NetworkAcl",
      "AWS::EC2::FlowLog",
    ]

    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_config_delivery_channel" "security_baseline" {
  count = var.enable_baseline_monitoring ? 1 : 0

  name           = "${var.project_name}-${var.environment}-delivery"
  s3_bucket_name = aws_s3_bucket.config_history[0].bucket
  s3_kms_key_arn = local.security_logs_key_arn

  depends_on = [
    aws_s3_bucket_policy.config_history,
    aws_s3_bucket_server_side_encryption_configuration.config_history,
    aws_s3_bucket_versioning.config_history
  ]
}

resource "aws_config_configuration_recorder_status" "security_baseline" {
  count = var.enable_baseline_monitoring ? 1 : 0

  name       = aws_config_configuration_recorder.security_baseline[0].name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.security_baseline
  ]
}

moved {
  from = aws_config_configuration_recorder.security_baseline
  to   = aws_config_configuration_recorder.security_baseline[0]
}

moved {
  from = aws_config_delivery_channel.security_baseline
  to   = aws_config_delivery_channel.security_baseline[0]
}

moved {
  from = aws_config_configuration_recorder_status.security_baseline
  to   = aws_config_configuration_recorder_status.security_baseline[0]
}
