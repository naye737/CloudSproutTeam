resource "aws_instance" "monitoring_server" {
  ami                    = "ami-08fe4e7862fb0d4c2" # Amazon Linux 2
  instance_type          = "t3.medium"
  key_name               = "NAYE_key"
  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]

  # IAM Role 연결
  iam_instance_profile = aws_iam_instance_profile.prometheus_instance_profile.name

  # ✅ EBS 볼륨을 `gp3`로 설정
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # ✅ 사용자 데이터 (User Data) - Docker, Prometheus, Grafana 자동 실행
  user_data = <<-EOF
    #!/bin/bash
    sudo amazon-linux-extras enable docker
    sudo yum install -y docker

    # Docker 서비스 시작 및 활성화
    sudo systemctl start docker
    sudo systemctl enable docker

    # Docker 그룹에 ec2-user 추가
    sudo usermod -aG docker ec2-user

    # Docker Compose 다운로드 및 권한 설정
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # 작업 디렉토리 생성
    mkdir -p /home/ec2-user/monitoring
    cd /home/ec2-user/monitoring

    # ✅ Prometheus 설정 파일 생성
    cat <<EOT > prometheus.yml
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'node-exporter-dynamic'
        ec2_sd_configs:
          - region: ap-northeast-2
            port: 9100
        relabel_configs:
          - source_labels: [__meta_ec2_private_ip]
            regex: '(.*)'
            replacement: 'PLACEHOLDER:9100'
            action: replace
            target_label: __address__
    EOT

    # sed로 placeholder 치환
    sed -i 's/PLACEHOLDER/$${1}/g' /home/ec2-user/monitoring/prometheus.yml

    # ✅ Loki 설정 파일 생성
    cat <<EOT > loki-config.yaml
    auth_enabled: false

    server:
      http_listen_port: 3100
      

    ingester:
      lifecycler:
        address: 127.0.0.1
        ring:
          kvstore:
            store: inmemory
          replication_factor: 1
        final_sleep: 0s
      chunk_idle_period: 5m
      chunk_retain_period: 30s
      

    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h

    storage_config:
      boltdb_shipper:
        active_index_directory: /loki/index
        cache_location: /loki/cache
      filesystem:
        directory: /loki/chunks

    limits_config:
      retention_period: 744h
    
    compactor:
      working_directory: /loki/compactor
      shared_store: filesystem
    EOT

    # ✅ Promtail 설정 파일 생성
    cat <<EOT > promtail-config.yaml
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      - job_name: Monitoring-logs
        static_configs:
          - targets:
              - localhost
            labels:
              job: Monitoring-logs
              __path__: /var/log/*
    EOT


    # ✅ Docker Compose 파일 생성
    cat <<EOT > docker-compose.yml
    version: '3.8'

    services:
      prometheus:
        image: prom/prometheus:latest
        container_name: prometheus
        restart: always  # ✅ 컨테이너가 죽어도 자동 재시작
        ports:
          - "9090:9090"
        volumes:
          - ./prometheus.yml:/etc/prometheus/prometheus.yml
          - prometheus_data:/prometheus
        networks:
          - monitoring
        depends_on:
          - node-exporter

      grafana:
        image: grafana/grafana:latest
        container_name: grafana
        restart: always
        ports:
          - "3000:3000"
        volumes:
          - grafana_data:/var/lib/grafana
        environment:
          - GF_SECURITY_ADMIN_USER=admin  # ✅ 기본 관리자 계정 추가
          - GF_SECURITY_ADMIN_PASSWORD=cloudee123
        networks:
          - monitoring
        depends_on:
          - prometheus

      node-exporter:
        image: prom/node-exporter:latest
        container_name: node-exporter
        restart: always
        ports:
          - "9100:9100"
        networks:
          - monitoring
      
      loki:
        image: grafana/loki:latest
        container_name: loki
        restart: always
        ports:
          - "3100:3100"
        command: -config.file=/etc/loki/local-config.yaml -config.expand-env=true
        volumes:
          - ./loki-config.yaml:/etc/loki/local-config.yaml -config.expand-env=true
          
        networks:
          - monitoring

      promtail:
        image: grafana/promtail:2.4.1
        container_name: promtail
        restart: always
        volumes:
          - /var/log:/var/log
          - ./promtail-config.yaml:/etc/promtail/config.yaml
        command: -config.file=/etc/promtail/config.yaml
        networks:
          - monitoring


    networks:
      monitoring:
        driver: bridge

    volumes:
      prometheus_data:
      grafana_data:
      
    EOT

    # Docker Compose 실행
    docker-compose up -d
  EOF

  tags = {
    Name = "Monitoring-Server"
  }
}

# Prometheus + Grafana의 퍼블릭 IP 출력
output "monitoring_server_ip" {
  value = aws_instance.monitoring_server.public_ip
}

# 모니터링 서버 Private IP 조회
data "aws_instance" "monitoring_server" {
  filter {
    name   = "tag:Name"
    values = ["Monitoring-Server"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_instance.monitoring_server] # 의존성 추가
}

# Private IP 출력
output "monitoring_server_private_ip" {
  value = data.aws_instance.monitoring_server.private_ip
}