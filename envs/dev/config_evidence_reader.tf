data "aws_iam_policy_document" "config_evidence_reader_trust" {
  statement {
    sid     = "AllowTerraformOperatorAssumeRoleWithMFA"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-operator"
      ]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "config_evidence_reader" {
  name                 = "ConfigEvidenceReadRole"
  description          = "Read-only verification role for this project's AWS Config evidence"
  assume_role_policy   = data.aws_iam_policy_document.config_evidence_reader_trust.json
  max_session_duration = 3600
  permissions_boundary = var.config_reader_boundary_arn
}

data "aws_iam_policy_document" "config_evidence_reader_permissions" {
  statement {
    sid     = "ReadConfigEvidenceMetadata"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      "${aws_s3_bucket.config_history.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
    ]
  }

  statement {
    sid       = "ListConfigEvidencePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.config_history.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
      ]
    }
  }

  statement {
    sid       = "DenyKMSOperations"
    effect    = "Deny"
    actions   = ["kms:*"]
    resources = [aws_kms_key.security_logs.arn]
  }

  statement {
    sid       = "DenyRoleChaining"
    effect    = "Deny"
    actions   = ["sts:AssumeRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "config_evidence_reader" {
  name   = "ReadConfigEvidenceMetadata"
  role   = aws_iam_role.config_evidence_reader.name
  policy = data.aws_iam_policy_document.config_evidence_reader_permissions.json
}
