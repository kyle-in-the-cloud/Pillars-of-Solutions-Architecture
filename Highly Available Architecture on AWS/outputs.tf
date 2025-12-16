output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.medicare-alb.dns_name
}

output "route53_name_servers" {
  description = "The name servers for the Route 53 hosted zone"
  value       = aws_route53_zone.medicare-hosted-zone.name_servers
}

output "failover_website_endpoint" {
  description = "The endpoint of the S3 failover website"
  value       = aws_s3_bucket_website_configuration.medicare_failover-static-site.website_endpoint
}
