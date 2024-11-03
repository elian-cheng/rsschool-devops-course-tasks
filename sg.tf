resource "aws_security_group" "K8S_public_sg" {
  name        = "K8S public sg"
  description = "Allow HTTP and SSH access"
  vpc_id      = aws_vpc.K8S_vpc.id

  # Allow all TCP traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound TCP traffic"
  }

  # Allow ICMP (ping)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ICMP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "K8S public sg"
  }
}

resource "aws_security_group" "K8S_private_sg" {
  name        = "K8S private sg"
  description = "Allow traffic from public subnet and outbound to internet"
  vpc_id      = aws_vpc.K8S_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [aws_security_group.K8S_public_sg.id] # Allow traffic from bastion
    description     = "Allow inbound traffic from public subnets"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "K8S private sg"
  }
}
