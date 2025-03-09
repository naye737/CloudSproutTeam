# ✅ Application Load Balancer (ALB 설정)
resource "aws_lb" "was_alb" {
  name               = "was-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false
}

# ✅ Auto Scaling Group (EC2 인스턴스 자동 확장)
resource "aws_autoscaling_group" "was_asg" {
  depends_on = [aws_lb.was_alb, aws_lb_target_group.was_target_group]

  launch_template {
    id      = aws_launch_template.was_template.id
    version = "$Latest"
  }

  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  target_group_arns = [aws_lb_target_group.was_target_group.arn]

  tag {
    key                 = "Name"
    value               = "was-instance"
    propagate_at_launch = true
  }
}

# ✅ ACM SSL 인증서 생성 (HTTPS 적용)
resource "aws_acm_certificate" "alb_ssl_cert" {
  domain_name       = "*.cloudee.today"
  validation_method = "DNS"

  tags = {
    Name = "ALB-SSL-Cert"
  }
}

# ✅ ALB Target Group (먼저 생성되어야 함)
resource "aws_lb_target_group" "was_target_group" {
  name     = "was-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    protocol            = "HTTP"
    path                = "/healthz"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# ✅ HTTPS Listener (ALB → Target Group 연결)
resource "aws_lb_listener" "https_listener" {
  depends_on        = [aws_lb_target_group.was_target_group] # ✅ Target Group이 먼저 생성되도록 설정
  load_balancer_arn = aws_lb.was_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.alb_ssl_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was_target_group.arn
  }
}

# ✅ HTTPS API 요청 처리 ("/api/*")
resource "aws_lb_listener_rule" "https_api_rule" {
  listener_arn = aws_lb_listener.https_listener.arn
  priority     = 10  # 우선순위 설정 (낮을수록 먼저 적용됨)

  condition {
    path_pattern {
      values = ["/api/*"]  # ✅ "/api" 이하 모든 요청을 처리
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was_target_group.arn
  }
}

# ✅ HTTP Listener (포트 80 → 포트 443 리디렉트)
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.was_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301" # 영구 리디렉션
    }
  }
}
