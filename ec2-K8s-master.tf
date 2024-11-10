data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
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

  user_data = <<-EOF
              #!/bin/bash
              set -e
              hostnamectl set-hostname "master-node"
              sudo apt-get update -y
              sudo apt-get install -y curl apt-transport-https git

              # Install k3s with public IP in TLS SAN
              curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl -s 2ip.io)" sh -

              # Wait for k3s to be ready
              while ! kubectl get nodes; do
                echo "Waiting for k3s to be ready..."
                sleep 10
              done

              # Setup kubeconfig
              mkdir -p ~/.kube
              sudo chmod 644 /etc/rancher/k3s/k3s.yaml
              sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
              sudo chown $(id -u):$(id -g) ~/.kube/config

              # Wait for node to be ready
              while [[ $(kubectl get nodes --no-headers 2>/dev/null | grep "Ready" | wc -l) -eq 0 ]]; do
                echo "Waiting for node to be ready..."
                sleep 10
              done

              # Install Helm
              curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
              sudo apt-get update -y
              sudo apt-get install -y helm

              # Clone the WordPress repository
              mkdir -p /home/ubuntu/helm
              git clone https://github.com/elian-cheng/rsschool-devops-task5-wordpress /home/ubuntu/helm

              # Install WordPress using Helm
              helm install my-wordpress /home/ubuntu/helm/wordpress --set wordpress.service.nodePort=32000

              # Ensure the services are running
              kubectl get pods -A
              EOF

  tags = {
    Name = "K8S K3s Master"
  }
}