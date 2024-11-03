# Public Route Table
resource "aws_route_table" "K8S_public_rt" {
  vpc_id = aws_vpc.K8S_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.K8S_igw.id
  }

  tags = {
    Name = "K8S Public Route Table"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "K8S_public_ra" {
  count          = length(aws_subnet.K8S_public_subnet)
  subnet_id      = aws_subnet.K8S_public_subnet[count.index].id
  route_table_id = aws_route_table.K8S_public_rt.id
}

# Private Route Table
resource "aws_route_table" "K8S_private_rt" {
  vpc_id = aws_vpc.K8S_vpc.id

  tags = {
    Name = "K8S Private Route Table"
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "K8S_private_ra" {
  count          = length(aws_subnet.K8S_private_subnet)
  subnet_id      = aws_subnet.K8S_private_subnet[count.index].id
  route_table_id = aws_route_table.K8S_private_rt.id
}

# Route outbound traffic from Private Route Table through NAT Gateway
resource "aws_route" "K8S_private_nat_route" {
  route_table_id         = aws_route_table.K8S_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.K8S_nat_gw.id
  depends_on             = [aws_nat_gateway.K8S_nat_gw]
}
