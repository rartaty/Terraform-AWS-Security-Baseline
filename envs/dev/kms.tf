resource "aws_kms_key" "security_logs" {
  count    = var.enable_security_logs_key ? 1 : 0
  provider = aws.kms_retirement

  description              = "KMS key for security logs, initially CloudTrail"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 30
  policy                   = data.aws_iam_policy_document.security_logs_key_policy[0].json

  lifecycle {
    # Staged retirement only: review the saved one-key plan before any apply.
    prevent_destroy = false
  }
}

moved {
  from = aws_kms_key.security_logs
  to   = aws_kms_key.security_logs[0]
}

locals {
  security_logs_key_arn = var.enable_security_logs_key ? aws_kms_key.security_logs[0].arn : var.retired_security_logs_key_arn
}

data "aws_iam_policy_document" "security_logs_key_policy" {
  count = var.enable_security_logs_key ? 1 : 0

  lifecycle {
    precondition {
      condition     = (var.kms_retirement_role_arn == null) == (var.kms_retirement_expires_at == null)
      error_message = "Configure retirement role ARN and expiry together, or leave both null."
    }
    precondition {
      condition     = var.kms_retirement_role_arn == null ? true : split(":", var.kms_retirement_role_arn)[4] == data.aws_caller_identity.current.account_id
      error_message = "The retirement role must belong to this AWS account."
    }
  }
  # Optional grant only: scheduling still requires a separately reviewed operation.
  dynamic "statement" {
    for_each = var.kms_retirement_role_arn == null ? [] : [var.kms_retirement_role_arn]

    content {
      sid       = "AllowTemporaryRetirementInspection"
      effect    = "Allow"
      actions   = ["kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:RequestedRegion"
        values   = [var.aws_region]
      }
      condition {
        test     = "DateLessThan"
        variable = "aws:CurrentTime"
        values   = [var.kms_retirement_expires_at]
      }
    }
  }
  dynamic "statement" {
    for_each = var.kms_retirement_role_arn == null ? [] : [var.kms_retirement_role_arn]

    content {
      sid       = "AllowTemporaryThirtyDayRetirement"
      effect    = "Allow"
      actions   = ["kms:ScheduleKeyDeletion"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:RequestedRegion"
        values   = [var.aws_region]
      }
      condition {
        test     = "DateLessThan"
        variable = "aws:CurrentTime"
        values   = [var.kms_retirement_expires_at]
      }
      condition {
        test     = "NumericEquals"
        variable = "kms:ScheduleKeyDeletionPendingWindowInDays"
        values   = ["30"]
      }
    }
  }
  dynamic "statement" {
    for_each = var.kms_retirement_role_arn == null ? [] : [1]

    content {
      sid       = "AllowAccountCancelDeletionForRecovery"
      effect    = "Allow"
      actions   = ["kms:CancelKeyDeletion"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      }
    }
  }
  dynamic "statement" {
    for_each = var.enable_phase7_config_audit ? [1] : []

    content {
      sid    = "AllowTemporaryPhase7ConfigAuditDecrypt"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [aws_iam_role.phase7_config_audit[0].arn]
      }

      actions   = ["kms:Decrypt"]
      resources = ["*"]

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
  }
  statement {
    sid    = "AllowLogReaderDecryptCloudTrailLogs"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cloudtrail_log_reader[0].arn]
    }

    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values = [
        "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${local.cloudtrail_name}"
      ]
    }
  }
  statement {
    sid    = "AllowCloudTrailDescribeKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.cloudtrail_name}"
      ]
    }
  }
  statement {
    sid    = "AllowCloudTrailGenerateDataKeys"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.cloudtrail_name}"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values = [
        "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/${local.cloudtrail_name}"
      ]
    }
  }
  statement {
    sid    = "AllowAWSConfigUseOfKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:config:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
  statement {
    sid    = "AllowTerraformExecutionRoleKeyAdministration"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TerraformExecutionRole"
      ]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:UpdateKeyDescription",
      "kms:GetKeyRotationStatus",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:ListResourceTags",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:EnableKey",
      "kms:CancelKeyDeletion"
    ]

    resources = ["*"]
  }
  statement {
    sid    = "AllowAccountKeyPolicyRecovery"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy"
    ]

    resources = ["*"]
  }
}
