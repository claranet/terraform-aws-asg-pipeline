output "pipeline_target" {
  value = module.asg.pipeline_target
}

output "url" {
  value = "http://${aws_alb.this.dns_name}/"
}
