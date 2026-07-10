output "wp_alb_dns_name" {
  value = aws_lb.wp_web.dns_name
}

output "wp_db_availability_zone" {
  value = aws_db_instance.wp.availability_zone
}

output "wp_db_endpoint" {
  value = aws_db_instance.wp.address
}

output "wp_efs_file_system_id" {
  value = aws_efs_file_system.wp.id
}

output "wp_efs_file_system_number_of_mount_targets" {
  value = aws_efs_file_system.wp.number_of_mount_targets
}
