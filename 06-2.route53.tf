# AWS Route 53 Zone (이미 존재하는 호스팅 영역 사용)
data "aws_route53_zone" "cloudee" {
  name         = "cloudee.today"
  private_zone = false
}

# ALB에 대한 Route 53 A 레코드 (ALIAS)
resource "aws_route53_record" "alb_record" {
  zone_id = data.aws_route53_zone.cloudee.zone_id
  name    = "api.cloudee.today"
  type    = "A"

  alias {
    name                   = aws_lb.was_alb.dns_name
    zone_id                = aws_lb.was_alb.zone_id
    evaluate_target_health = true
  }
}

# CloudFront에 대한 Route 53 A 레코드 (ALIAS)
resource "aws_route53_record" "cloudfront_record" {
  zone_id = data.aws_route53_zone.cloudee.zone_id
  name    = "www.cloudee.today"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.frontend_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
