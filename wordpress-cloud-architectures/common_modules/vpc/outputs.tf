output "id" {
  value = aws_vpc.main.id
}

output "subnet_id_web_A" {
  value = aws_subnet.web_A.id
}

output "subnet_id_web_B" {
  value = aws_subnet.web_B.id
}

output "subnet_id_web_C" {
  value = aws_subnet.web_C.id
}
