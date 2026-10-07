output "lab_details" {
  description = "Private test identifiers; do not publish the output or raw evidence."
  value = {
    firewall_arn  = aws_networkfirewall_firewall.lab.arn
    firewall_name = aws_networkfirewall_firewall.lab.name
    endpoint_id   = local.endpoint_id
    rule_action   = var.rule_action
    signature_id  = 750001
    log_groups    = { for name, group in aws_cloudwatch_log_group.lab : name => group.name }
    instances = { for name, instance in aws_instance.lab : name => {
      id         = instance.id
      private_ip = instance.private_ip
    } }
    subnets = { for name, subnet in aws_subnet.lab : name => subnet.id }
  }
}
