resource "aws_securityhub_account_v2" "essentials" {
}

resource "aws_securityhub_account" "cspm" {
  enable_default_standards  = false
  auto_enable_controls      = false
  control_finding_generator = "SECURITY_CONTROL"
}

resource "aws_securityhub_standards_subscription" "aws_foundational_security_best_practices" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [
    aws_securityhub_account.cspm
  ]
}
