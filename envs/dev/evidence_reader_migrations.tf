moved {
  from = aws_iam_role.cloudtrail_log_reader
  to   = aws_iam_role.cloudtrail_log_reader[0]
}

moved {
  from = aws_iam_role_policy.cloudtrail_log_reader
  to   = aws_iam_role_policy.cloudtrail_log_reader[0]
}

moved {
  from = aws_iam_role.config_evidence_reader
  to   = aws_iam_role.config_evidence_reader[0]
}

moved {
  from = aws_iam_role_policy.config_evidence_reader
  to   = aws_iam_role_policy.config_evidence_reader[0]
}
