output "wp_ec2_availability_zone" {
  value = aws_instance.wp.availability_zone
}

output "wp_ec2_public_ip" {
  value = aws_instance.wp.public_ip
}
