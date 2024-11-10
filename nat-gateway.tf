# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "K8S_nat_eip" {}

# Create the NAT Gateway in a public subnet
resource "aws_nat_gateway" "K8S_nat_gw" {
  allocation_id = aws_eip.K8S_nat_eip.id
  subnet_id     = aws_subnet.K8S_public_subnet[0].id
  depends_on    = [aws_internet_gateway.K8S_igw]

  tags = {
    Name = "K8S NAT Gateway"
  }
}
