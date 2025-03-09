# ✅ Launch Template (EC2 설정)
resource "aws_launch_template" "was_template" {
  name                   = "was-template"
  image_id               = "ami-0f6aa39cbe021540b" # ✅ 적절한 AMI ID 사용
  instance_type          = "t3.small"
  key_name               = "NAYE_key" # ✅ SSH Key 설정
  vpc_security_group_ids = [aws_security_group.was_sg.id]

  # ✅ RDS 생성이 완료된 후 실행되도록 보장
  depends_on = [null_resource.wait_for_rds]

  # ✅ IAM Instance Profile 추가 (SSM 연결 가능)
  iam_instance_profile {
    name = aws_iam_instance_profile.was_instance_profile.name
  }

  # ✅ EBS 볼륨을 `gp3`로 설정 (로그 저장 고려하여 20GB)
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20   # ✅ 로그 저장 고려하여 20GB로 확장
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  # ✅ User Data를 BASE64 인코딩하여 전달
  user_data = base64encode(<<EOF
#!/bin/bash

# ✅ Promtail 설정 디렉토리 생성
mkdir -p /home/ec2-user/promtail
cd /home/ec2-user/promtail

# ✅ 모니터링 서버 Private IP 가져오기
MONITORING_SERVER_PRIVATE_IP="${data.aws_instance.monitoring_server.private_ip}"

# ✅ Promtail 설정 파일 생성
cat <<EOT > promtail-config.yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${aws_instance.monitoring_server.private_ip}:3100/loki/api/v1/push

scrape_configs:
  - job_name: was
    static_configs:
      - targets:
          - localhost
        labels:
          job: was
          __path__: /var/log/*
EOT

# ✅ Promtail Docker Compose 파일 생성
cat <<EOT > docker-compose.yml
version: '3.8'

services:
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: always
    volumes:
      - ./promtail-config.yaml:/etc/promtail/config.yaml
      - /var/log:/var/log
    command: -config.file=/etc/promtail/config.yaml
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
EOT

# ✅ Docker Compose 실행 명확한 경로 설정
cd /home/ec2-user/promtail
docker-compose up -d

echo "✅ Promtail Docker Compose 설치 및 실행 완료!"

EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "was-instance"
      monitoring = "yes"  # ✅ 중요! Prometheus가 발견하는 태그
    }
  }
}

# ✅ IAM Role 생성 (EC2에서 SSM 연결 가능하도록 설정)
resource "aws_iam_role" "was_role" {
  name = "was-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# ✅ IAM Policy (EC2에서 SSM 사용 가능하도록 설정)
resource "aws_iam_policy_attachment" "ssm_policy_attach" {
  name       = "was-ssm-policy"
  roles      = [aws_iam_role.was_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ✅ IAM Instance Profile 생성 (EC2에서 사용할 IAM Role 연결)
resource "aws_iam_instance_profile" "was_instance_profile" {
  name = "was-instance-profile-1"
  role = aws_iam_role.was_role.name  
}