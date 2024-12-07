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
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl -s 2ip.io)" sh -s -

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

# Install Prometheus using Bitnami Helm chart with inline values
helm upgrade --install prometheus bitnami/kube-prometheus \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.service.type=LoadBalancer \
  --set prometheus.service.port=9090 \
  --set prometheus.resources.limits.cpu=200m \
  --set prometheus.resources.limits.memory=256Mi \
  --set prometheus.resources.requests.cpu=100m \
  --set prometheus.resources.requests.memory=128Mi \
  --set prometheus.retention=7d \
  --set prometheus.replicas=1 \
  --set alertmanager.enabled=false \
  --set nodeExporter.resources.limits.cpu=50m \
  --set nodeExporter.resources.limits.memory=64Mi \
  --set nodeExporter.resources.requests.cpu=25m \
  --set nodeExporter.resources.requests.memory=32Mi \
  --set kubeStateMetrics.resources.limits.cpu=100m \
  --set kubeStateMetrics.resources.limits.memory=128Mi \
  --set kubeStateMetrics.resources.requests.cpu=50m \
  --set kubeStateMetrics.resources.requests.memory=64Mi \
  --set prometheusOperator.enabled=true \
  --set prometheusOperator.replicas=1

# Define dashboard JSON file
DASHBOARD_JSON='{
  "dashboard": {
    "id": null,
    "uid": "system_metrics_dashboard",
    "title": "System Metrics",
    "tags": ["system", "metrics"],
    "timezone": "browser",
    "schemaVersion": 26,
    "version": 1,
    "panels": [
      {
        "type": "graph",
        "title": "CPU Usage",
        "targets": [
          {
            "target": "avg(rate(node_cpu_seconds_total{mode='user'}[1m])) by (instance)"
          }
        ],
        "xaxis": {
          "mode": "time"
        },
        "yaxis": {
          "format": "percent"
        }
      },
      {
        "type": "graph",
        "title": "Memory Usage",
        "targets": [
          {
            "target": "avg(rate(node_memory_Active_bytes[1m])) by (instance)"
          }
        ],
        "xaxis": {
          "mode": "time"
        },
        "yaxis": {
          "format": "bytes"
        }
      },
      {
        "type": "graph",
        "title": "Disk Usage",
        "targets": [
          {
            "target": "avg(rate(node_filesystem_size_bytes[1m])) by (instance)"
          }
        ],
        "xaxis": {
          "mode": "time"
        },
        "yaxis": {
          "format": "bytes"
        }
      }
    ]
  }
}'

# Write dashboard JSON to file
DASHBOARD_PATH="/opt/grafana/dashboards/system_metrics.json"
mkdir -p "$(dirname "$DASHBOARD_PATH")"
echo "$DASHBOARD_JSON" > "$DASHBOARD_PATH"

# Fetch the EC2 instance's public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Install Grafana
helm upgrade --install grafana bitnami/grafana \
  --namespace monitoring \
  --create-namespace \
  --set service.type=LoadBalancer \
  --set service.port=3000 \
  --set admin.password="${var.grafana_admin_password}" \
  --set dashboards.default.system_metrics.file="$DASHBOARD_PATH" \
  --set datasources.default.datasources[0].name=Prometheus \
  --set datasources.default.datasources[0].type=prometheus \
  --set datasources.default.datasources[0].url="http://$PUBLIC_IP:9090" \
  --set datasources.default.datasources[0].access=direct \
  --set datasources.default.datasources[0].isDefault=true

# Verify installation
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Expose Prometheus service on LoadBalancer
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
# Expose Grafana service on LoadBalancer
kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Get public IP for services
PROMETHEUS_IP=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Output accessible URLs
echo "Prometheus is accessible at http://$PROMETHEUS_IP:9090"
echo "Grafana is accessible at http://$GRAFANA_IP:3000"

# Ensure the services are running
kubectl get pods -A
