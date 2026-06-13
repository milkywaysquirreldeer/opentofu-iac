output "vpc-id" {
  value = aws_vpc.vpc.id
}

output "subnet-webA-id" {
  value = aws_subnet.web-A.id
}

output "subnet-webB-id" {
  value = aws_subnet.web-B.id
}

output "subnet-webC-id" {
  value = aws_subnet.web-C.id
}
