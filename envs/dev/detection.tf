locals {
  guardduty_disabled_features = toset([
    "S3_DATA_EVENTS",
    "EKS_AUDIT_LOGS",
    "EBS_MALWARE_PROTECTION",
    "LAMBDA_NETWORK_LOGS",
    "RUNTIME_MONITORING",
    "AI_PROTECTION",
    "AI_ANALYST"
  ])
}

resource "aws_accessanalyzer_analyzer" "external_access" {
  analyzer_name = "${var.project_name}-${var.environment}-external-access"
  type          = "ACCOUNT"
}

resource "aws_guardduty_detector" "security_monitoring" {
  enable                       = true
  finding_publishing_frequency = "SIX_HOURS"
}

resource "aws_guardduty_detector_feature" "disabled" {
  for_each = local.guardduty_disabled_features

  detector_id = aws_guardduty_detector.security_monitoring.id
  name        = each.value
  status      = "DISABLED"

  dynamic "additional_configuration" {
    for_each = each.key == "RUNTIME_MONITORING" ? {
      EC2_AGENT_MANAGEMENT         = "DISABLED"
      ECS_FARGATE_AGENT_MANAGEMENT = "DISABLED"
      EKS_ADDON_MANAGEMENT         = "DISABLED"
    } : {}

    content {
      name   = additional_configuration.key
      status = additional_configuration.value
    }
  }
}

moved {
  from = aws_guardduty_detector_feature.disabled["RDS_LOGIN_EVENTS"]
  to   = aws_guardduty_detector_feature.rds_login_events
}

resource "aws_guardduty_detector_feature" "rds_login_events" {
  detector_id = aws_guardduty_detector.security_monitoring.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "DISABLED"

  lifecycle {
    # Temporary provider compatibility exception for RDS only.
    # Audit the full additional configuration with GetDetector; do not ignore status.
    # Remove this exception after provider support and a clean plan are verified.
    ignore_changes = [additional_configuration]
  }
}
