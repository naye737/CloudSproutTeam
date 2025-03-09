resource "aws_wafv2_web_acl" "frontend_waf" {
  provider    = aws.us_east_1  
  name        = "frontend-waf"
  description = "WAF for CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "frontendWAF"
    sampled_requests_enabled   = true
  }

  # ✅ AWS Managed Rules
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesBotControlRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 40
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  # 🔹 사용자 정의 규칙 - Bad Bot 차단
  rule {
    name     = "BlockBadBot"
    priority = 50
    action {
      block {}
    }
    statement {
      byte_match_statement {
        search_string = "badbot"
        field_to_match {
          single_header {
            name = "user-agent"
          }
        }
        positional_constraint = "CONTAINS"
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockBadBot"
      sampled_requests_enabled   = true
    }
  }

  # 🔹 2. DDoS 보호 (AWS IP Reputation List 사용)
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 60
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # 🔹 3. API 속도 제한 (Rate Limiting)
  rule {
    name     = "RateLimitAPI"
    priority = 70
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitAPI"
      sampled_requests_enabled   = true
    }
  }

  # 🔹 4. Captcha 보호 (추가된 기능)
  rule {
    name     = "CaptchaProtection"
    priority = 80
    action {
      captcha {}
    }
    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CaptchaProtection"
      sampled_requests_enabled   = true
    }
  }

  # 🔹 5. 허용된 HTTP 메서드만 허용
  rule {
    name     = "AllowOnlySpecificMethods"
    priority = 90
    action {
      block {}
    }
    statement {
      not_statement {
        statement {
          or_statement {
            statement {
              byte_match_statement {
                search_string = "GET"
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
            statement {
              byte_match_statement {
                search_string = "POST"
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
            statement {
              byte_match_statement {
                search_string = "PUT"
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
            statement {
              byte_match_statement {
                search_string = "DELETE"
                field_to_match {
                  method {}
                }
                positional_constraint = "EXACTLY"
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowOnlySpecificMethods"
      sampled_requests_enabled   = true
    }
  }
}
