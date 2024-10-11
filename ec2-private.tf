resource "aws_instance" "K8S_private_instance" {
  ami               = data.aws_ami.ubuntu_ami.id
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.K8S_private_subnet[0].id # Use the first private subnet
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  key_name               = aws_key_pair.ec2_auth_key.id
  vpc_security_group_ids = [aws_security_group.K8S_private_sg.id]

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo Private Instance Server > /var/www/html/index.html'
                EOF

  tags = {
    Name = "K8S Private Instance"
  }
}
