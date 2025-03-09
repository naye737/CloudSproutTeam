# ✅ CloudFront CDN 설정
resource "aws_cloudfront_distribution" "frontend_cdn" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend_website.website_endpoint  # ✅ 변경됨 (S3 웹사이트 엔드포인트 사용)
    origin_id   = "S3-Frontend-Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # ✅ CloudFront는 웹사이트 엔드포인트를 HTTP로만 접근
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Frontend-Origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  aliases = ["www.cloudee.today"]

  viewer_certificate {
    acm_certificate_arn      = "arn:aws:acm:us-east-1:619071325933:certificate/55a72970-401e-471e-ae43-ca894941212e"  # ACM 인증서 ARN
    ssl_support_method        = "sni-only"
    minimum_protocol_version  = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "Ticketing-Frontend-CDN"
  }
}
