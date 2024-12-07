# Network ACL for public subnets (allows HTTP/SSH from anywhere)
resource "aws_network_acl" "K8S_public_nacl" {
  vpc_id = aws_vpc.K8S_vpc.id

  # Allow all inbound traffic
  ingress {
    rule_no    = 100
    protocol   = "-1" # All protocols
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }

  # Allow all outbound traffic
  egress {
    protocol   = -1
    rule_no    = 100
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }

  tags = {
    Name = "K8S Public NACL"
  }
}

# Associate NACL with Public Subnets
resource "aws_network_acl_association" "K8S_public_nacl_association" {
  count          = length(var.public_subnet_cidrs)
  network_acl_id = aws_network_acl.K8S_public_nacl.id
  subnet_id      = aws_subnet.K8S_public_subnet[count.index].id
}

# Network ACL for private subnets (restricted to VPC CIDR)
resource "aws_network_acl" "K8S_private_nacl" {
  vpc_id = aws_vpc.K8S_vpc.id

  # Allow all inbound traffic
  ingress {
    rule_no    = 100
    protocol   = "-1" # All protocols
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }

  # Allow all outbound traffic
  egress {
    rule_no    = 100
    protocol   = -1 # All protocols
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }

  tags = {
    Name = "K8S Private NACL"
  }
}

# Associate NACL with Private Subnets
resource "aws_network_acl_association" "K8S_private_nacl_association" {
  count          = length(var.private_subnet_cidrs)
  network_acl_id = aws_network_acl.K8S_private_nacl.id
  subnet_id      = aws_subnet.K8S_private_subnet[count.index].id
}
