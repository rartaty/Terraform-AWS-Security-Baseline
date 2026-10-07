data "aws_ami" "lab" {
  owners = ["amazon"]

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "lab" {
  for_each = toset(["client", "server"])

  ami                         = data.aws_ami.lab.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.lab[each.key].id
  private_ip                  = each.key == "client" ? local.client_ip : local.server_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.lab[each.key].id]
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/${each.key}.sh.tftpl", {
    server_ip = local.server_ip
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    kms_key_id            = var.ebs_key_arn
    delete_on_termination = true
  }
  credit_specification {
    cpu_credits = "standard"
  }
  volume_tags = merge(local.common_tags, { Name = "${local.prefix}-${each.key}-root" })
  tags        = { Name = "${local.prefix}-${each.key}" }

  lifecycle {
    precondition {
      condition = (
        data.aws_ami.lab.root_device_name == "/dev/xvda" &&
        length(data.aws_ami.lab.block_device_mappings) == 1 &&
        length([for mapping in data.aws_ami.lab.block_device_mappings : mapping
          if mapping.device_name == data.aws_ami.lab.root_device_name
        ]) == 1 &&
        alltrue([for mapping in data.aws_ami.lab.block_device_mappings :
          try(tonumber(mapping.ebs["volume_size"]) <= 8, false)
          if mapping.device_name == data.aws_ami.lab.root_device_name
        ])
      )
      error_message = "Recheck the pinned AMI root device and required root volume size."
    }
  }
  depends_on = [
    aws_route.peer,
    aws_route_table_association.lab,
    aws_vpc_security_group_egress_rule.client,
    aws_vpc_security_group_ingress_rule.server,
    aws_networkfirewall_logging_configuration.lab
  ]
}
