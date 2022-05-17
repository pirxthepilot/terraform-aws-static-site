#######################################
# ACM Provider (requires us-east-1)
#######################################
provider "aws" {
  alias  = "acm"
  region = "us-east-1"
}


#######################################
# Cloudfront Origin Access Identity
#######################################
resource "aws_cloudfront_origin_access_identity" "static_site" {
  comment = var.domain
}

#######################################
# IAM Policy 
#######################################
data "aws_iam_policy_document" "read_static_site_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.static_site.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.static_site.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.static_site.iam_arn]
    }
  }
}

#######################################
# S3 Bucket
#######################################
resource "aws_s3_bucket" "static_site" {
  bucket = var.domain
}

#######################################
# S3 Bucket ACL
#######################################
resource "aws_s3_bucket_acl" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  acl    = "private"
}

#######################################
# S3 Bucket Policy
#######################################
resource "aws_s3_bucket_policy" "read_static_site" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.read_static_site_bucket.json
}

#######################################
# S3 Bucket Public Access Block
#######################################
resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

#######################################
# TLS Certificate
#######################################
resource "aws_acm_certificate" "static_site" {
  provider = aws.acm

  domain_name               = var.domain
  subject_alternative_names = [for s in var.subdomains : "${s}.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

#######################################
# Certificate Validation - DNS
#######################################
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.static_site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

#######################################
# Certificate Validation - ACM
#######################################
resource "aws_acm_certificate_validation" "static_site" {
  provider = aws.acm

  certificate_arn         = aws_acm_certificate.static_site.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

#######################################
# Route 53 Records
#######################################
resource "aws_route53_record" "static_site" {
  zone_id = var.route53_zone_id

  name = var.domain
  type = "A"

  alias {
    name                   = aws_cloudfront_distribution.static_site.domain_name
    zone_id                = aws_cloudfront_distribution.static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "static_site_subdomains" {
  for_each = toset(var.subdomains)

  zone_id = var.route53_zone_id

  name    = each.value
  type    = "CNAME"
  ttl     = 300
  records = [var.domain]

}

#######################################
# Cloudfront Distribution
#######################################
resource "aws_cloudfront_distribution" "static_site" {
  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id   = var.domain

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static_site.cloudfront_access_identity_path
    }
  }

  aliases = concat([var.domain], [for s in var.subdomains : "${s}.${var.domain}"])

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "CDN for ${var.domain}"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.domain

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.static_site.arn
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.cache_ttl.min
    default_ttl            = var.cache_ttl.default
    max_ttl                = var.cache_ttl.max
  }

  price_class = var.price_class

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.static_site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 404
    response_page_path    = var.html_404
  }

  restrictions {
    geo_restriction {
      restriction_type = var.block_ofac_countries ? "blacklist" : "none"
      locations        = var.block_ofac_countries ? var.ofac_countries : []
    }
  }
}

#######################################
# Cloudfront Function
#######################################
resource "aws_cloudfront_function" "static_site" {
  name    = "${replace(var.domain, ".", "_")}_index_rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "index.html rewrite for S3 origin"
  publish = true
  code    = templatefile("${path.module}/function.js.tftpl", { domain = var.domain, subdomains = var.subdomains })
}
