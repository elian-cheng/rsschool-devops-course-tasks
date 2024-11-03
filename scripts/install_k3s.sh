#!/bin/bash
set -o errexit   # abort on nonzero exit status
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

# https://www.digitalocean.com/community/tutorials/how-to-setup-k3s-kubernetes-cluster-on-ubuntu
 # Set hostname
hostnamectl set-hostname "master-node"

# Update and install dependencies
sudo apt-get update -y
sudo apt-get install -y curl apt-transport-https

# Disable UFW firewall (optional, depending on your security requirements)
sudo ufw disable
# installing k3s
curl -sfL https://get.k3s.io | sh -
# OR
# Install K3s with external IP for API server access
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl -s 2ip.io)" sh -

# Configure kubeconfig for kubectl
sudo mkdir -p /home/ubuntu/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Create Jenkins namespace
kubectl create namespace jenkins

# Define PersistentVolume and PersistentVolumeClaim in the script directly or download it
cat <<EOL | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
spec:
  capacity:
    storage: 8Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/tmp/jenkins-volume"
---
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
      storage: 8Gi
EOL

 # Apply Jenkins RBAC configuration
cat <<EOL | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins
rules:
  - apiGroups: ["*"]
     resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins
  subjects:
    - kind: ServiceAccount
      name: jenkins
      namespace: jenkins
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: jenkins
EOL
                
# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install -y helm
                
# Add Jenkins Helm chart repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Create Persistent Volume directory
mkdir -p /tmp/jenkins-volume
chown -R 1000:1000 /tmp/jenkins-volume
                
# Install Jenkins using Helm with custom values including security plugins
helm install jenkins jenkins/jenkins --namespace jenkins \
  --set controller.serviceType=LoadBalancer \
  --set persistence.enabled=true \
  --set persistence.size=8Gi \
  --set persistence.existingClaim=jenkins-pvc \
  --set controller.installPlugins="cloudbees-credentials,git,workflow-aggregator,jacoco,jacoco,configuration-as-code"

# make kubeconfig avaliable without sudo
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# check status
sudo systemctl status k3s
kubectl get all -n kube-system

# check nodes
kubectl get nodes

# deploy simple workload
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml

# Install autocompletion in kubectl
#    https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-shell-autocompletion
sudo apt install -y bash-completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
kubectl get pods


