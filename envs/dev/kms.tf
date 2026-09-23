resource "aws_kms_key" "security_logs" {
  description              = "KMS key for security logs, initially CloudTrail"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365
  deletion_window_in_days  = 30
  policy                   = data.aws_iam_policy_document.security_logs_key_policy.json

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "security_logs_key_policy" {
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
      identifiers = [aws_iam_role.cloudtrail_log_reader.arn]
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
