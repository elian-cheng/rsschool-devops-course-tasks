data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "template_file" "user_data" {
  template = file("install_k3s.sh")

  vars = {
    grafana_admin_password = var.grafana_admin_password
  }
}

resource "aws_instance" "K8S_K3S_master" {
  ami               = data.aws_ami.ubuntu_ami.id
  instance_type     = var.k8s_master_instance_type
  subnet_id         = aws_subnet.K8S_public_subnet[0].id
  availability_zone = element(data.aws_availability_zones.available.names, 0)

  associate_public_ip_address = true

  key_name = var.access_key_name

  vpc_security_group_ids = [aws_security_group.K8S_public_sg.id]

  root_block_device {
    volume_size           = var.k8s_master_node_disk.size
    volume_type           = var.k8s_master_node_disk.type
    delete_on_termination = true
  }

  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "K8S K3s Master"
  }
}