# IAM Role 생성
resource "aws_iam_role" "prometheus_role" {
  name = "PrometheusEC2DiscoveryRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM 정책 생성 (EC2 인스턴스 조회 권한)
resource "aws_iam_policy" "prometheus_policy" {
  name        = "PrometheusEC2DiscoveryPolicy"
  description = "Allows Prometheus to discover EC2 instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM 정책을 Role에 연결
resource "aws_iam_role_policy_attachment" "prometheus_attach" {
  role       = aws_iam_role.prometheus_role.name
  policy_arn = aws_iam_policy.prometheus_policy.arn
}

# IAM Instance Profile 생성 (EC2에 Role 연결하려면 필요)
resource "aws_iam_instance_profile" "prometheus_instance_profile" {
  name = "PrometheusInstanceProfile"
  role = aws_iam_role.prometheus_role.name
}
