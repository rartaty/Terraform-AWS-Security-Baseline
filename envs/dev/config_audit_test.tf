locals {
  phase7_config_audit_object_arn = "${aws_s3_bucket.config_history.arn}/${var.phase7_config_audit_object_key}"
}

resource "aws_iam_role" "phase7_config_audit" {
  count = var.enable_phase7_config_audit ? 1 : 0

  name                 = "Phase7ConfigAuditReadRole"
  description          = "Temporary read access to one Config history object"
  assume_role_policy   = data.aws_iam_policy_document.config_evidence_reader_trust.json
  max_session_duration = 3600

  lifecycle {
    precondition {
      condition = (
        startswith(
          var.phase7_config_audit_object_key,
          "AWSLogs/${data.aws_caller_identity.current.account_id}/Config/${var.aws_region}/"
        )
        && endswith(var.phase7_config_audit_object_key, ".json.gz")
        && length(regexall("[*?]", var.phase7_config_audit_object_key)) == 0
      )
      error_message = "Specify one exact Config history object key for this account and region; wildcards are not allowed."
    }
  }

  tags = {
    Purpose = "phase7-config-audit-test"
  }
}

data "aws_iam_policy_document" "phase7_config_audit" {
  count = var.enable_phase7_config_audit ? 1 : 0

  statement {
    sid       = "ReadOneConfigHistoryObject"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [local.phase7_config_audit_object_arn]
  }

  statement {
    sid       = "DecryptOneConfigHistoryObjectThroughS3"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.security_logs.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = [local.phase7_config_audit_object_arn]
    }
  }

  statement {
    sid       = "DenyRoleChaining"
    effect    = "Deny"
    actions   = ["sts:AssumeRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "phase7_config_audit" {
  count = var.enable_phase7_config_audit ? 1 : 0

  name   = "ReadOneConfigHistoryObject"
  role   = aws_iam_role.phase7_config_audit[0].name
  policy = data.aws_iam_policy_document.phase7_config_audit[0].json
}
