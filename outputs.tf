output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.static_site.id
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.static_site.arn
}

output "s3_bucket_id" {
  value = aws_s3_bucket.static_site.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.static_site.arn
}

output "s3_bucket_domain_name" {
  value = aws_s3_bucket.static_site.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  value = aws_s3_bucket.static_site.bucket_regional_domain_name
}
