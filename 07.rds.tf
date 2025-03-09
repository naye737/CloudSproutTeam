# Aurora Multi-Master 클러스터 생성
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier = "aurora-multi-master-cluster"
  engine             = "aurora-mysql"
  # engine_version         = "8.0.32.mysql_aurora.3.05.2"  # 최신 Aurora MySQL 버전
  database_name           = "concert"
  master_username         = "cloudee"
  master_password         = "jehj240424!"
  backup_retention_period = 7
  preferred_backup_window = "02:00-03:00"
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  storage_encrypted       = true # 데이터 암호화 활성화
  skip_final_snapshot     = true
}

# 첫 번째 Aurora Multi-Master 인스턴스 (쓰기/읽기 가능)
resource "aws_rds_cluster_instance" "aurora_instance_1" {
  cluster_identifier   = aws_rds_cluster.aurora_cluster.id
  instance_class       = "db.t3.medium"
  engine               = "aurora-mysql"
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
}

# 두 번째 Aurora Multi-Master 인스턴스 (쓰기/읽기 가능)
resource "aws_rds_cluster_instance" "aurora_instance_2" {
  cluster_identifier   = aws_rds_cluster.aurora_cluster.id
  instance_class       = "db.t3.medium"
  engine               = "aurora-mysql"
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
}

# Aurora 클러스터 엔드포인트 (애플리케이션에서 이 엔드포인트로 연결)
output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}

# RDS 서브넷 그룹 (Aurora가 프라이빗 서브넷에 배포되도록 설정)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags = {
    Name = "rds-subnet-group"
  }
}

# ✅ RDS 생성이 완료될 때까지 대기
resource "null_resource" "wait_for_rds" {
  depends_on = [aws_rds_cluster.aurora_cluster, aws_rds_cluster_instance.aurora_instance_1, aws_rds_cluster_instance.aurora_instance_2]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for RDS to become available..."
      while true; do
        STATUS=$(aws rds describe-db-clusters --db-cluster-identifier aurora-multi-master-cluster --query 'DBClusters[0].Status' --output text)
        echo "Current RDS status: $STATUS"
        if [ "$STATUS" == "available" ]; then
          echo "✅ RDS is now available!"
          break
        fi
        sleep 10
      done
    EOT
  }
}