resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "charlie-puth-ticket"

  tags = {
    Name = "Frontend-Bucket"
  }
}

# 객체 소유권을 ACL 비활성화 (BucketOwnerEnforced)
resource "aws_s3_bucket_ownership_controls" "frontend_bucket_ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_block" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = true   # ACL 비활성화
  block_public_policy     = false
  ignore_public_acls      = true   # ACL 무시
  restrict_public_buckets = false
}

# S3 버킷 정책 (퍼블릭 읽기 권한 허용)
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  depends_on = [
    aws_s3_bucket_public_access_block.frontend_bucket_block,
    aws_s3_bucket_ownership_controls.frontend_bucket_ownership  # 객체 소유권 리소스 추가
  ]

  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}

# S3에 index.html 업로드
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.frontend_bucket.id
  key    = "index.html"
  source = "C:/CloudSprout0219/index.html"  # 로컬 파일 경로 지정
  content_type = "text/html"
}

# S3에 charlie-puth-tour.jpg 업로드
resource "aws_s3_object" "charlie_puth_tour_jpg" {
  bucket = aws_s3_bucket.frontend_bucket.id
  key    = "charlie-puth-tour.jpg"
  source = "C:/CloudSprout0219/charlie-puth-tour.jpg"  # 로컬 파일 경로 지정
  content_type = "image/jpeg"
}

# S3에 concert-bg.jpg 업로드
resource "aws_s3_object" "concert_bg_jpg" {
  bucket = aws_s3_bucket.frontend_bucket.id
  key    = "concert-bg.jpg"
  source = "C:/CloudSprout0219/concert-bg.jpg"  # 로컬 파일 경로 지정
  content_type = "image/jpeg"
}

# S3에 style.css 업로드
resource "aws_s3_object" "style_css" {
  bucket = aws_s3_bucket.frontend_bucket.id
  key    = "style.css"
  source = "C:/CloudSprout0219/style.css"  # 로컬 파일 경로 지정
  content_type = "text/css"
}