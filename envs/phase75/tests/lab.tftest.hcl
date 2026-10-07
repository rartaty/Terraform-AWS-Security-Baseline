# All AWS calls are mocked. No credentials or paid resources are used.
mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "10.70.0.0/16"
      tags = {
        Project = "terraform-aws-security-baseline"
        Purpose = "phase7-network-learning"
      }
    }
  }
  mock_data "aws_ami" {
    defaults = {
      root_device_name = "/dev/xvda"
      block_device_mappings = [{
        device_name = "/dev/xvda"
        ebs         = { volume_size = "8" }
      }]
    }
  }
  mock_resource "aws_networkfirewall_firewall" {
    defaults = {
      arn = "arn:aws:network-firewall:ap-northeast-1:${join("", [for i in range(12) : "1"])}:firewall/mock"
      firewall_status = [{
        sync_states = [{
          availability_zone = "ap-northeast-1a"
          attachment        = [{ endpoint_id = "vpce-mock-lab" }]
        }]
      }]
    }
  }
  mock_resource "aws_networkfirewall_rule_group" {
    defaults = {
      arn = "arn:aws:network-firewall:ap-northeast-1:${join("", [for i in range(12) : "1"])}:stateful-rulegroup/mock"
    }
  }
  mock_resource "aws_networkfirewall_firewall_policy" {
    defaults = {
      arn = "arn:aws:network-firewall:ap-northeast-1:${join("", [for i in range(12) : "1"])}:firewall-policy/mock"
    }
  }
  mock_resource "aws_instance" {
    defaults = {
      key_name             = ""
      iam_instance_profile = ""
    }
  }
}

variables {
  account_id        = join("", [for i in range(12) : "1"])
  vpc_id            = "vpc-${join("", [for i in range(17) : "a"])}"
  availability_zone = "ap-northeast-1a"
  ami_id            = "ami-${join("", [for i in range(17) : "a"])}"
  ebs_key_arn       = "arn:aws:kms:ap-northeast-1:${join("", [for i in range(12) : "1"])}:key/${join("-", [for n in [8, 4, 4, 4, 12] : join("", [for i in range(n) : "a"])])}"
}

run "alert_configuration" {
  command = apply

  assert {
    condition     = length(aws_subnet.lab) == 3 && length(aws_route_table.lab) == 3 && length(aws_route_table_association.lab) == 3
    error_message = "Own only three Lab subnets, route tables and explicit associations."
  }
  assert {
    condition     = alltrue([for subnet in aws_subnet.lab : subnet.availability_zone == "ap-northeast-1a" && !subnet.map_public_ip_on_launch])
    error_message = "Use one AZ and no subnet public IPv4 auto-assignment."
  }
  assert {
    condition = (
      length(aws_route.peer) == 2 &&
      aws_route.peer["client"].destination_cidr_block == "10.70.22.0/24" &&
      aws_route.peer["server"].destination_cidr_block == "10.70.20.0/24" &&
      alltrue([for route in aws_route.peer : route.vpc_endpoint_id == "vpce-mock-lab"])
    )
    error_message = "Both peer-subnet routes must cross the same Firewall endpoint."
  }
  assert {
    condition = nonsensitive(alltrue([for instance in aws_instance.lab :
      instance.instance_type == "t3.micro" &&
      !instance.associate_public_ip_address &&
      instance.metadata_options[0].http_tokens == "required" &&
      instance.credit_specification[0].cpu_credits == "standard" &&
      one(instance.root_block_device).encrypted &&
      one(instance.root_block_device).volume_size == 8 &&
      one(instance.root_block_device).volume_type == "gp3" &&
      one(instance.root_block_device).delete_on_termination &&
      one(instance.root_block_device).kms_key_id == var.ebs_key_arn &&
      instance.volume_tags.Purpose == "phase75-firewall-test" &&
      contains([null, ""], instance.iam_instance_profile) && contains([null, ""], instance.key_name)
    ]))
    error_message = "Keep both instances private, IMDSv2, standard credits and tagged encrypted 8 GiB gp3."
  }
  assert {
    condition = (
      aws_vpc_security_group_egress_rule.client.cidr_ipv4 == "10.70.22.10/32" &&
      aws_vpc_security_group_ingress_rule.server.cidr_ipv4 == "10.70.20.10/32" &&
      aws_vpc_security_group_egress_rule.client.from_port == 8080 &&
      aws_vpc_security_group_egress_rule.client.to_port == 8080 &&
      aws_vpc_security_group_ingress_rule.server.from_port == 8080 &&
      aws_vpc_security_group_ingress_rule.server.to_port == 8080
    )
    error_message = "SG permits only peer IP TCP 8080; no SSH or global access."
  }
  assert {
    condition = (
      length(aws_networkfirewall_firewall.lab.subnet_mapping) == 1 &&
      !aws_networkfirewall_firewall.lab.delete_protection &&
      !aws_networkfirewall_firewall.lab.subnet_change_protection &&
      !aws_networkfirewall_firewall.lab.firewall_policy_change_protection &&
      aws_networkfirewall_firewall_policy.lab.firewall_policy[0].stateful_engine_options[0].rule_order == "STRICT_ORDER" &&
      aws_networkfirewall_rule_group.http.rule_group[0].stateful_rule_options[0].rule_order == "STRICT_ORDER" &&
      startswith(aws_networkfirewall_rule_group.http.rule_group[0].rules_source[0].rules_string, "alert http ") &&
      strcontains(aws_networkfirewall_rule_group.http.rule_group[0].rules_source[0].rules_string, "sid:750001;")
    )
    error_message = "One removable Firewall and strict-order fixed-signature ALERT rules are required."
  }
  assert {
    condition     = alltrue([for group in aws_cloudwatch_log_group.lab : group.retention_in_days == 1 && group.log_group_class == "STANDARD" && group.kms_key_id == null])
    error_message = "Use two 1-day Standard Lab groups without adding a customer KMS key."
  }
}

run "drop_same_signature" {
  command = plan
  variables {
    rule_action = "drop"
  }
  assert {
    condition = (
      startswith(aws_networkfirewall_rule_group.http.rule_group[0].rules_source[0].rules_string, "drop http ") &&
      strcontains(aws_networkfirewall_rule_group.http.rule_group[0].rules_source[0].rules_string, "sid:750001;") &&
      local.client_ip == "10.70.20.10" && local.server_ip == "10.70.22.10"
    )
    error_message = "DROP must preserve the signature and fixed peer IPs."
  }
}

run "reject_other_rule_action" {
  command = plan
  variables {
    rule_action = "pass"
  }
  expect_failures = [var.rule_action]
}

run "reject_wrong_vpc" {
  command = plan
  override_data {
    target = data.aws_vpc.learning
    values = {
      cidr_block = "10.99.0.0/16"
      tags       = { Project = "other", Purpose = "other" }
    }
  }
  expect_failures = [aws_subnet.lab]
}

run "reject_oversized_ami_root" {
  command = plan
  override_data {
    target = data.aws_ami.lab
    values = {
      root_device_name = "/dev/xvda"
      block_device_mappings = [{
        device_name = "/dev/xvda"
        ebs         = { volume_size = "16" }
      }]
    }
  }
  expect_failures = [aws_instance.lab]
}
