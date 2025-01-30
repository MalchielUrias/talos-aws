output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the load balancer"
  value       = aws_lb.this.zone_id
}

output "tg_arn" {
  description = "arn of target group"
  value = aws_lb_target_group.this.arn
}