output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}
# output "acm_certificate_arn" {
#   value = aws_acm_certificate.cert.arn
# }

# output "acm_certificate_domain_validation_options" {
#   value = aws_acm_certificate.cert.domain_validation_options
# }
