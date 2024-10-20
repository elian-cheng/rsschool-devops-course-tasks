resource "aws_instance" "K8S_K3S_master" {
  ami               = data.aws_ami.ubuntu_ami.id
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.K8S_private_subnet[0].id # Use the first private subnet
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  key_name               = k8s-cluster
  vpc_security_group_ids = [aws_security_group.K8S_private_sg.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update -y
                sudo apt-get install -y curl
                sudo ufw disable
                curl -sfL https://get.k3s.io | sh -
                sudo chmod 644 /etc/rancher/k3s/k3s.yaml
                EOF

  tags = {
    Name = "K8S K3s Master"
  }
}
