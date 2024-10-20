resource "aws_subnet" "K8S_public_subnet" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.K8S_vpc.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  map_public_ip_on_launch = true

  tags = {
    Name = "K8S Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "K8S_private_subnet" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.K8S_vpc.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "K8S Private Subnet ${count.index + 1}"
  }
}
