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

# Install Prometheus using Bitnami Helm chart
echo "Installing Prometheus using Bitnami Helm chart..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Define values.yaml content
VALUES_YAML=$(cat <<EOF
serverFiles:
  alerting_rules.yml:
    groups:
      - name: k8s-alerts
        rules:
          - alert: HighCpuUtilization
            expr: |
              sum(rate(node_cpu_seconds_total{mode!="idle"}[2m])) / sum(machine_cpu_cores) > 0.8
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "High CPU utilization detected on node {{ $labels.instance }}"
              description: "Node {{ $labels.instance }} is using over 80% CPU for the last 1 minute."

          - alert: CpuCoresCapacityExhausted
            expr: |
              sum(machine_cpu_cores) - sum(rate(node_cpu_seconds_total{mode!="idle"}[2m])) < 1
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "CPU cores capacity almost exhausted on node {{ $labels.instance }}"
              description: "Node {{ $labels.instance }} has less than 1 cores available for allocation."
alertmanagerFiles:
  alertmanager.yml:
    global:
      resolve_timeout: 1m

    receivers:
      - name: "gmail-notifications"
        email_configs:
          - to: eliang.cheng@gmail.com
            from: eliang.cheng@gmail.com
            smarthost: smtp.gmail.com:587
            auth_username: eliang.cheng@gmail.com
            auth_identity: eliang.cheng@gmail.com
            auth_password: "${google_password}"
            send_resolved: true
            headers:
              subject: "Prometheus - Alert"
              text: "{{ range .Alerts }} Hi, \n{{ .Annotations.summary }} \n {{ .Annotations.description }} {{end}} "

      - name: "all-notifications"
        email_configs:
          - to: eliang.cheng@gmail.com
            from: eliang.cheng@gmail.com
            smarthost: smtp.gmail.com:587
            auth_username: eliang.cheng@gmail.com
            auth_identity: eliang.cheng@gmail.com
            auth_password: "${google_password}"
            send_resolved: true
            headers:
              subject: "Prometheus - Alert"
              text: "{{ range .Alerts }} Hi, \n{{ .Annotations.summary }} \n {{ .Annotations.description }} {{end}} "

    route:
      group_wait: 10s
      group_interval: 2m
      repeat_interval: 2m
      receiver: "all-notifications"
EOF
)

# Write values.yaml to file
VALUES_PATH="/opt/conf/helm/prometheus/values.yaml"
mkdir -p "$(dirname "$VALUES_PATH")"
echo "$VALUES_YAML" > "$VALUES_PATH"

# Install Prometheus using Bitnami Helm chart with values file
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  -f "$VALUES_PATH" \
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

# Fetch the EC2 instance's public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Install Grafana
helm upgrade --install grafana bitnami/grafana \
  --namespace monitoring \
  --create-namespace \
  --set service.type=LoadBalancer \
  --set service.port=3000 \
  --set admin.password="${grafana_admin_password}" \
  --set datasources.default.datasources[0].name=Prometheus \
  --set datasources.default.datasources[0].type=prometheus \
  --set datasources.default.datasources[0].url="http://$PUBLIC_IP:80" \
  --set datasources.default.datasources[0].access=proxy \
  --set datasources.default.datasources[0].isDefault=true

# Verify installation
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Expose Grafana service on LoadBalancer
kubectl patch svc grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Get public IP for services
PROMETHEUS_IP=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Output accessible URLs
echo "Prometheus is accessible at http://$PUBLIC_IP:80"
echo "Grafana is accessible at http://$PUBLIC_IP:3000"

kubectl get pods -A