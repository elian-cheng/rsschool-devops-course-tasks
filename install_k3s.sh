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
install_package "docker.io"

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
docker --version || { echo "Docker installation failed."; exit 1; }
echo "Docker installed successfully."

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

# Create SonarQube namespace
kubectl create namespace sonarqube || echo "Namespace sonarqube already exists."

# Add SonarQube Helm repository and update
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update

# Create values.yaml for SonarQube
cat <<EOF > values.yaml
persistence:
  enabled: true
  storageClass: local-path
  size: 10Gi

resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1"
EOF


# Install SonarQube using Helm
helm install my-sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --set persistence.enabled=true \
  --set persistence.storageClass=local-path \
  --set service.type=LoadBalancer

# Wait for SonarQube to be ready
while [[ $(kubectl get pod my-sonarqube-sonarqube-0 -n sonarqube -o jsonpath='{.status.containerStatuses[*].ready}' 2>/dev/null | grep -c "true") -ne 1 ]]; do
  echo "Waiting for SonarQube pod to be ready..."
  sleep 10
done

# Expose SonarQube service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: sonarqube
  namespace: sonarqube
spec:
  type: LoadBalancer
  ports:
    - port: 9000
      targetPort: 9000
  selector:
    app: sonarqube-sonarqube
EOF

# Create Jenkins namespace
kubectl create namespace jenkins || echo "Namespace jenkins already exists."

# Check StorageClass and create default if not exists
kubectl get storageclass &>/dev/null || {
    echo "No StorageClass found. Setting up a default StorageClass..."
    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
EOF
}

# Create PersistentVolumeClaim for Jenkins
echo "Creating PersistentVolumeClaim for Jenkins..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
EOF

# Add Jenkins Helm repository and update
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins using Helm
helm install my-jenkins jenkins/jenkins \
  --namespace jenkins \
  --set persistence.enabled=true \
  --set persistence.existingClaim=jenkins-pvc \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.requests.cpu=500m \
  --set controller.resources.limits.memory=2Gi \
  --set controller.resources.limits.cpu=1 \
  --set service.type=LoadBalancer \
  --set controller.containerSecurityContext.readOnlyRootFilesystem=false

# Wait for Jenkins to be ready
while [[ $(kubectl get pod -n jenkins -l app.kubernetes.io/component=jenkins-controller -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -c "true") -ne 2 ]]; do
  echo "Waiting for Jenkins pod to be ready..."
  sleep 10
done

# Install SonarQube plugin in Jenkins
kubectl exec -n jenkins svc/my-jenkins -c jenkins -- /bin/bash -c "jenkins-plugin-cli --plugins sonar"

# Restart Jenkins pod to apply the plugin
kubectl rollout restart statefulset my-jenkins -n jenkins

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: $PUBLIC_IP"
kubectl patch svc my-jenkins -n jenkins -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc sonarqube -n sonarqube -p '{"spec": {"type": "LoadBalancer"}}'

# Get Jenkins admin password
JENKINS_PASSWORD=$(kubectl exec -n jenkins svc/my-jenkins -c jenkins -- cat /run/secrets/additional/chart-admin-password)
[ -n "$JENKINS_PASSWORD" ] && echo "Jenkins admin password: $JENKINS_PASSWORD" || { echo "Failed to retrieve Jenkins admin password."; exit 1; }

echo "Jenkins is accessible at http://$PUBLIC_IP:8080"

# SonarQube URL
echo "SonarQube is accessible at http://$PUBLIC_IP:9000"

# Ensure the services are running
kubectl get pods -A