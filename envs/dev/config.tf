data "aws_iam_role" "config_service_linked" {
  name = "AWSServiceRoleForConfig"
}

resource "aws_config_configuration_recorder" "security_baseline" {
  name     = "${var.project_name}-${var.environment}-recorder"
  role_arn = data.aws_iam_role.config_service_linked.arn

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
  name           = "${var.project_name}-${var.environment}-delivery"
  s3_bucket_name = aws_s3_bucket.config_history.bucket
  s3_kms_key_arn = aws_kms_key.security_logs.arn

  depends_on = [
    aws_s3_bucket_policy.config_history,
    aws_s3_bucket_server_side_encryption_configuration.config_history,
    aws_s3_bucket_versioning.config_history
  ]
}

resource "aws_config_configuration_recorder_status" "security_baseline" {
  name       = aws_config_configuration_recorder.security_baseline.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.security_baseline
  ]
}
