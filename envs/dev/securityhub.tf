resource "aws_securityhub_account_v2" "essentials" {
  count = var.enable_baseline_monitoring ? 1 : 0
}

resource "aws_securityhub_account" "cspm" {
  count = var.enable_baseline_monitoring ? 1 : 0

  enable_default_standards  = false
  auto_enable_controls      = false
  control_finding_generator = "SECURITY_CONTROL"
}

resource "aws_securityhub_standards_subscription" "aws_foundational_security_best_practices" {
  count = var.enable_baseline_monitoring ? 1 : 0

  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [
    aws_securityhub_account.cspm
  ]
}

moved {
  from = aws_securityhub_account_v2.essentials
  to   = aws_securityhub_account_v2.essentials[0]
}

moved {
  from = aws_securityhub_account.cspm
  to   = aws_securityhub_account.cspm[0]
}

moved {
  from = aws_securityhub_standards_subscription.aws_foundational_security_best_practices
  to   = aws_securityhub_standards_subscription.aws_foundational_security_best_practices[0]
}
