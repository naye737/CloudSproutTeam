# ✅ ALB 보안 그룹
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "alb-security-group"

  # HTTP & HTTPS 외부 트래픽 허용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

# ✅ RDS 보안 그룹
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "rds-security-group"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC 내부에서만 접근 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}

# ✅ 모니터링 서버 (Prometheus + Grafana)
resource "aws_security_group" "monitoring_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "monitoring_sg"

  # ✅ Grafana 웹 UI (3000 포트) 
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["121.134.211.97/32"]  
  }

  # ✅ Prometheus 웹 UI (9090 포트) 
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["121.134.211.97/32"]  
  }

  # ✅ Prometheus <-> EC2 (Node Exporter) 통신 (내부 트래픽 허용)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # ✅ VPC 내부 트래픽 허용
  }

  # ✅ Prometheus <-> loki 통신 (내부 트래픽 허용)
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # ✅ VPC 내부 트래픽 허용
  }

  # ✅ 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ✅ WAS 보안 그룹
resource "aws_security_group" "was_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name   = "was-security-group"

  # ALB → WAS (Flask 서비스)
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    
    # ✅ ALB 내부에서만 접근 가능하도록 제한
    cidr_blocks = ["10.0.0.0/16"]
  }

  # 내부 VPC 내에서 WAS가 Node Exporter에 접근 가능하도록 설정
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # ✅ VPC 내부 트래픽 허용
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
