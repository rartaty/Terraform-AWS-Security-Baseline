resource "aws_security_group" "phase7_test_client" {
  count = var.enable_phase7_test ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-p7-client-"
  description = "Temporary Phase 7 test client"
  vpc_id      = aws_vpc.phase7_learning.id

  tags = {
    Name    = "${var.project_name}-${var.environment}-p7-client"
    Purpose = "phase7-network-test"
  }
}

resource "aws_security_group" "phase7_test_server" {
  count = var.enable_phase7_test ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-p7-server-"
  description = "Temporary Phase 7 test server"
  vpc_id      = aws_vpc.phase7_learning.id

  tags = {
    Name    = "${var.project_name}-${var.environment}-p7-server"
    Purpose = "phase7-network-test"
  }
}

resource "aws_vpc_security_group_egress_rule" "phase7_test_client" {
  for_each = var.enable_phase7_test ? toset(["8080", "8081"]) : toset([])

  security_group_id            = aws_security_group.phase7_test_client[0].id
  referenced_security_group_id = aws_security_group.phase7_test_server[0].id

  ip_protocol = "tcp"
  from_port   = tonumber(each.key)
  to_port     = tonumber(each.key)

  description = "Test client to server TCP ${each.key}"
}

resource "aws_vpc_security_group_ingress_rule" "phase7_test_server" {
  count = var.enable_phase7_test ? 1 : 0

  security_group_id            = aws_security_group.phase7_test_server[0].id
  referenced_security_group_id = aws_security_group.phase7_test_client[0].id

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080

  description = "Allow HTTP test from client security group"
}
data "aws_ssm_parameter" "phase7_test_ami" {
  count = var.enable_phase7_test ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "phase7_test_server" {
  count = var.enable_phase7_test ? 1 : 0

  ami           = data.aws_ssm_parameter.phase7_test_ami[0].value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.phase7["isolated_a"].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.phase7_test_server[0].id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data_replace_on_change = true

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/phase7-server.log /dev/console) 2>&1

    date -u
    /usr/bin/python3 --version

    mkdir -p /opt/phase7-http
    printf 'phase7-server-ok\n' > /opt/phase7-http/index.html

    cat > /etc/systemd/system/phase7-http.service <<'SERVICE'
    [Unit]
    Description=Phase 7 temporary HTTP server
    After=network.target

    [Service]
    User=nobody
    ExecStart=/usr/bin/python3 -u -m http.server 8080 --bind 0.0.0.0 --directory /opt/phase7-http
    Restart=on-failure
    StandardOutput=journal+console
    StandardError=journal+console

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable --now phase7-http.service
    systemctl is-active phase7-http.service
    echo "PHASE7_SERVER_STARTED"
  USERDATA

  depends_on = [
    aws_vpc_security_group_ingress_rule.phase7_test_server
  ]

  tags = {
    Name    = "${var.project_name}-${var.environment}-p7-server"
    Purpose = "phase7-network-test"
  }
}
resource "aws_instance" "phase7_test_client" {
  count = var.enable_phase7_test ? 1 : 0

  ami           = data.aws_ssm_parameter.phase7_test_ami[0].value
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.phase7["public_a"].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.phase7_test_client[0].id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data_replace_on_change = true

  user_data = <<-USERDATA
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee -a /var/log/phase7-client.log /dev/console) 2>&1

    /usr/bin/python3 -u - <<'PYTHON'
    import datetime
    import socket
    import time
    import urllib.request

    target = "${aws_instance.phase7_test_server[0].private_ip}"

    def log(message):
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        print(f"{now} {message}", flush=True)

    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    ready = False

    # BのHTTPサーバー起動を、回数を限定して待つ。
    for attempt in range(1, 31):
        try:
            with opener.open(f"http://{target}:8080/", timeout=3) as response:
                body = response.read(128).decode().strip()
                if response.status == 200 and body == "phase7-server-ok":
                    log(f"ALLOW_OK target={target} port=8080 attempt={attempt}")
                    ready = True
                    break
                log(f"ALLOW_UNEXPECTED body={body!r}")
        except Exception as error:
            log(f"ALLOW_WAIT attempt={attempt} error={error}")
        time.sleep(5)

    if not ready:
        log("TEST_INCOMPLETE: HTTP readiness check failed")
        raise SystemExit(1)

    # 許可・拒否の両方について、少数回の通信を記録する。
    for attempt in range(1, 4):
        try:
            with opener.open(f"http://{target}:8080/", timeout=3) as response:
                body = response.read(128).decode().strip()
                ok = response.status == 200 and body == "phase7-server-ok"
                log(f"ALLOW_CHECK attempt={attempt} ok={ok} target={target} port=8080")
        except Exception as error:
            log(f"ALLOW_FAILED attempt={attempt} error={error}")

        try:
            with socket.create_connection((target, 8081), timeout=3):
                log(f"DENY_UNEXPECTED_CONNECTED target={target} port=8081")
        except socket.timeout:
            log(f"DENY_TIMEOUT target={target} port=8081")
        except OSError as error:
            log(f"DENY_OTHER_ERROR target={target} port=8081 error={error}")

        time.sleep(5)

    log("TEST_ATTEMPTS_FINISHED: verify Flow Logs before judging the result")
    PYTHON
  USERDATA

  depends_on = [
    aws_vpc_security_group_egress_rule.phase7_test_client,
    aws_vpc_security_group_ingress_rule.phase7_test_server
  ]

  tags = {
    Name    = "${var.project_name}-${var.environment}-p7-client"
    Purpose = "phase7-network-test"
  }
}
