data "aws_iam_policy_document" "cloudtrail_log_reader_trust" {
  statement {
    sid     = "AllowTerraformOperatorAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-operator"
      ]
    }
  }
}

resource "aws_iam_role" "cloudtrail_log_reader" {
  count = var.enable_evidence_readers ? 1 : 0

  name                 = "CloudTrailLogReadRole"
  description          = "Read-only role for this project's CloudTrail logs"
  assume_role_policy   = data.aws_iam_policy_document.cloudtrail_log_reader_trust.json
  permissions_boundary = var.cloudtrail_reader_boundary_arn
}

data "aws_iam_policy_document" "cloudtrail_log_reader_permissions" {
  statement {
    sid     = "ReadCloudTrailLogsAndDigests"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      "${local.log_bucket_arns.cloudtrail}/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/*",
      "${local.log_bucket_arns.cloudtrail}/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail-Digest/*"
    ]
  }

  statement {
    sid       = "ListCloudTrailLogsAndDigests"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.log_bucket_arns.cloudtrail]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/*",
        "AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail-Digest/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "cloudtrail_log_reader" {
  count = var.enable_evidence_readers ? 1 : 0

  name   = "ReadCloudTrailLogsAndDigests"
  role   = aws_iam_role.cloudtrail_log_reader[0].name
  policy = data.aws_iam_policy_document.cloudtrail_log_reader_permissions.json
}
