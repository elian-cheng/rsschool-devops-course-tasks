resource "aws_internet_gateway" "K8S_igw" {
  vpc_id = aws_vpc.K8S_vpc.id

  tags = {
    Name = "K8S Internet Gateway"
  }
}
