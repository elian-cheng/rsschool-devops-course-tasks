output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.K8S_vpc.id
}

output "public_subnets" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.K8S_public_subnet[*].id
}

output "private_subnets" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.K8S_private_subnet[*].id
}

output "bastion_host_public_ip" {
  description = "The public IP of the bastion host"
  value       = aws_instance.K8S_bastion_host.public_ip
}

output "private_ec2_private_ip" {
  description = "The private IP of the private instance"
  value       = aws_instance.K8S_private_instance.private_ip
}
