data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "K8S_bastion_host" {
  ami               = data.aws_ami.ubuntu_ami.id
  instance_type     = "t3.micro"
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  subnet_id         = aws_subnet.K8S_public_subnet[0].id

  associate_public_ip_address = true

  key_name               = "k8s-cluster"
  vpc_security_group_ids = [aws_security_group.K8S_public_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo ufw disable
              mkdir -p /home/ubuntu/.ssh
              echo "${var.private_key}" > /home/ubuntu/.ssh/k8s-cluster.pem
              chmod 400 /home/ubuntu/.ssh/k8s-cluster.pem
              chown ubuntu:ubuntu /home/ubuntu/.ssh/k8s-cluster.pem
              EOF


  tags = {
    Name = "K8S Bastion Host"
  }
}

