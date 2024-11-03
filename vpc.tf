resource "aws_vpc" "K8S_vpc" {
  cidr_block = var.vpc_cidr

  # DNS Parameters in VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "K8S-VPC"
  }
}
