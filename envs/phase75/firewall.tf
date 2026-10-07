resource "aws_networkfirewall_rule_group" "http" {
  name        = "${local.prefix}-http-rule"
  description = "Harmless fixed HTTP URI probe; not a production default-deny policy"
  capacity    = 10
  type        = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
    rules_source {
      rules_string = "${var.rule_action} http ${local.client_ip} any -> ${local.server_ip} 8080 (msg:\"Phase75 harmless URI probe\"; flow:established,to_server; http.uri; content:\"/phase75-probe\"; sid:750001; rev:1;)"
    }
  }
  tags = { Name = "${local.prefix}-http-rule" }
}

resource "aws_networkfirewall_firewall_policy" "lab" {
  name = "${local.prefix}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_default_actions           = ["aws:alert_established"]
    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }
    stateful_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.http.arn
    }
  }
  tags = { Name = "${local.prefix}-policy" }
}

resource "aws_networkfirewall_firewall" "lab" {
  name                = "${local.prefix}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.lab.arn
  vpc_id              = data.aws_vpc.learning.id

  delete_protection                 = false
  firewall_policy_change_protection = false
  subnet_change_protection          = false

  subnet_mapping {
    subnet_id = aws_subnet.lab["inspection"].id
  }
  tags = { Name = "${local.prefix}-firewall" }

  timeouts {
    create = "20m"
    delete = "20m"
  }
  depends_on = [aws_route_table_association.lab]
}

# Import the two pre-created groups into this Lab state before the paid apply.
resource "aws_cloudwatch_log_group" "lab" {
  for_each = toset(["alert", "flow"])

  name              = "/aws/vendedlogs/network-firewall/phase75-${each.key}"
  retention_in_days = 1
  log_group_class   = "STANDARD"
  tags              = { Name = "${local.prefix}-${each.key}-logs" }
}

resource "aws_networkfirewall_logging_configuration" "lab" {
  firewall_arn = aws_networkfirewall_firewall.lab.arn

  logging_configuration {
    dynamic "log_destination_config" {
      for_each = aws_cloudwatch_log_group.lab
      content {
        log_destination_type = "CloudWatchLogs"
        log_type             = upper(log_destination_config.key)
        log_destination = {
          logGroup = log_destination_config.value.name
        }
      }
    }
  }
}
