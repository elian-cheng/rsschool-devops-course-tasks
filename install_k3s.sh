#!/bin/bash
set -e

max_attempts=10

# Function to wait for a condition
wait_for_condition() {
    local condition="$1"
    local max_attempts=$2
    local attempt_num=1
    while ! eval "$condition" && [ $attempt_num -le $max_attempts ]; do
        echo "Waiting for condition: $condition..."
        sleep 10
        ((attempt_num++))
    done
}

# Function to install packages
install_package() {
    local package=$1
    if ! command -v "$package" &>/dev/null; then
        echo "Installing $package..."
        sudo apt-get install -y "$package" || { echo "$package installation failed."; exit 1; }
    else
        echo "$package is already installed."
    fi
}

# Set hostname
hostnamectl set-hostname "master-node"

# Update and install dependencies
sudo apt-get update -y
install_package "curl"
install_package "apt-transport-https"
install_package "git"

# Install k3s with public IP in TLS SAN
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl -s 2ip.io)" sh -

# Wait for k3s to be ready
while ! kubectl get nodes; do
  echo "Waiting for k3s to be ready..."
  sleep 10
done

# Wait for kubeconfig to be available
wait_for_condition "[ -f /etc/rancher/k3s/k3s.yaml ]" $max_attempts
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "KUBECONFIG has been set to: $KUBECONFIG"

kubectl cluster-info || { echo "Kubernetes cluster is not reachable."; exit 1; }

mkdir -p ~/.kube && chmod 700 ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && chmod 600 ~/.kube/config
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo systemctl status k3s

# Wait for node to be ready
while [[ $(kubectl get nodes --no-headers 2>/dev/null | grep "Ready" | wc -l) -eq 0 ]]; do
  echo "Waiting for node to be ready..."
  sleep 10
done

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
command -v helm &>/dev/null || { echo "Helm installation failed."; exit 1; }

# Add Bitnami Helm repository and update
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Prometheus using Bitnami Helm chart
echo "Installing Prometheus using Bitnami Helm chart..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring || echo "Namespace monitoring already exists."

helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --set server.service.type=LoadBalancer \
  --set alertmanager.service.type=LoadBalancer \
  --set pushgateway.service.type=LoadBalancer

echo "Waiting for Prometheus to be ready..."
while [[ $(kubectl get pods -n monitoring -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -c "true") -ne 1 ]]; do
  echo "Waiting for Prometheus pod to be ready..."
  sleep 10
done

# Install Node Exporter
echo "Installing Node Exporter..."
helm install node-exporter prometheus-community/prometheus-node-exporter --namespace monitoring

# Install Kube State Metrics
echo "Installing Kube State Metrics..."
helm install kube-state-metrics prometheus-community/kube-state-metrics --namespace monitoring

# Verify Prometheus installation
echo "Verifying Prometheus installation..."
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: $PUBLIC_IP"
echo "Prometheus is accessible at http://$PUBLIC_IP:80"

# Ensure the services are running
kubectl get pods -A