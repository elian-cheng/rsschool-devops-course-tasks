# rsschool-devops-course-tasks

Repo for RS School AWS DevOps course

## Overview

This repository contains Terraform configuration files to set up basic networking infrastructure for a Kubernetes cluster in AWS. The setup includes a VPC, public and private subnets, routing configurations, a NAT Gateway, and optional resources like a bastion host. An S3 bucket is used to store the Terraform state, and an IAM role is configured to allow GitHub Actions to interact with AWS.

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [Terraform](https://www.terraform.io/downloads.html) installed
- A GitHub account

## Installation

1. **Clone the Repository**:

```bash
1. git clone https://github.com/elian-cheng/rsschool-devops-course-tasks.git
2. cd rsschool-devops-course-tasks
```

2. **Configure the AWS CLI**:
   Ensure you have configured the AWS CLI with the credentials of your IAM user:

```bash
aws configure
```

3. **Set Up GitHub Secrets**:
   In your GitHub repository, navigate to Settings > Secrets and Variables > Actions. Add the following secrets:
   - AWS_ACCOUNT_ID: Your AWS account ID.
   - AWS_REGION: The AWS region (e.g., us-east-1).
   - AWS_EC2_PRIVATE_KEY: private key to connect to private subnet instances from bastion host

# Terraform Configuration

## Variables

The Terraform configurations use the following variables:

- **aws_region**: The AWS region where resources will be deployed.
- **terraform_state_bucket**: The S3 bucket for storing Terraform state.
- **account_id**: Your AWS account ID.
- **github_org**: Your GitHub organization or username.
- **github_repo**: The name of your GitHub repository.
- **vpc_cidr**: CIDR block for the VPC.
- **public_subnet_cidrs**: CIDR blocks for the public subnets.
- **private_subnet_cidrs**: CIDR blocks for the private subnets.
- **private_key**: The private key used for SSH access to the private instance.

## File Structure

- **.github/workflows/terraform.yml**: GitHub Actions workflow configuration.
- **main.tf**: Provider configuration and backend settings.
- **variables.tf**: Variable definitions.
- **vpc.tf**: VPC definition.
- **subnets.tf**: Subnets definitions.
- **sg.tf**: Security groups definitions.
- **routing.tf**: Routes definitions.
- **nacl.tf**: Network ACL definitions.
- **ig.tf**: Internet gateway definition.
- **ec2-bastion.tf**: Bastion host definition.
- **ec2-K8s-master.tf**: Private instance definition (in private subnet) for K8s master.
- **outputs.tf**: Resources outputs.

## Workflow Overview

The GitHub Actions workflow consists of three jobs:

- **terraform-check**: Checks the formatting of Terraform files.
- **terraform-plan**: Initializes Terraform and creates an execution plan.
- **terraform-apply**: Applies the changes to the AWS infrastructure (only on push to main).

## Usage

To deploy the infrastructure:

1. Make changes to your Terraform files.
2. Push your changes to the main branch or create a pull request.
3. Monitor the Actions tab for the workflow run status.

## Testing Your Workflow

To verify that your GitHub Actions workflow works:

1. **Push Your Changes**:

   - Make any change (e.g., a comment in a README file) and push it to the main branch or create a pull request.

2. **Check the Workflow Run**:

   - Navigate to the Actions tab in your GitHub repository to view the list of workflow runs.
   - Click on the most recent run to view details, checking the status of each job.

3. **Verify Outputs**:

   - Ensure that the terraform plan job runs successfully and outputs the planned actions correctly.
   - If you're pushing to the main branch, check that terraform apply executes without errors.

4. SSH into the Bastion Host:

```bash
ssh -i path/to/your/private_key.pem ubuntu@<bastion_host_public_ip>
```

5. SSH into the K3s Master Node from the Bastion Host:

```bash
ssh -i /home/ubuntu/.ssh/k8s-cluster.pem ubuntu@<k3s_master_private_ip>
```

6. Copy the k3s.yaml File to your local machine:

```bash
scp -i /home/ubuntu/.ssh/k8s-cluster.pem ubuntu@<k3s_master_private_ip>:/etc/rancher/k3s/k3s.yaml /path/to/local/directory/k3s.yaml
```

7. Set the KUBECONFIG Environment Variable on your local machine:

```bash
export KUBECONFIG=/path/to/local/directory/k3s.yaml
```

8. Verify the Cluster:

```bash
kubectl get nodes
```

9. Deploy the Simple Workload:

```bash
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml
```

10. Set Up Monitoring with Prometheus and Grafana:

```bash
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml
```

```bash
kubectl apply -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/grafana/templates/deployment.yaml
```

## Monitoring

To see the monitoring setup with Prometheus and Grafana actually working, follow these steps:

1. Get Prometheus Service Information:
   kubectl get svc -n monitoring

2. Port Forward Prometheus Service:
   kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

3. Access Prometheus:
   Open your web browser and go to http://localhost:9090.
4. Get Grafana Service Information:
   kubectl get svc -n monitoring

5. Port Forward Grafana Service:
   kubectl port-forward -n monitoring svc/grafana 3000:3000
6. Access Grafana:
   Open your web browser and go to http://localhost:3000

7. Log in to Grafana:
   Default Credentials:
   Username: admin
   Password: admin (or check the Grafana deployment for the actual password)
   Change Password: You will be prompted to change the password on the first login.
8. Add Prometheus as a Data Source in Grafana:

- Navigate to Configuration:
  Click on the gear icon (⚙️) on the left sidebar.
  Select "Data Sources".
- Add Data Source:
  Click "Add data source".
  Select "Prometheus".
  Set the URL to http://prometheus-operated.monitoring.svc.cluster.local:9090 (or use the appropriate service name and namespace).
- Save & Test: Click "Save & Test" to verify the connection. 9. Create Dashboards in Grafana:
- Import Pre-built Dashboards:
  Click on the "+" icon on the left sidebar.
  Select "Import".
  Use a dashboard ID from Grafana's [dashboard repository](https://grafana.com/grafana/dashboards) (e.g., 6417 for Kubernetes cluster monitoring).
- Configure the Dashboard:
  Set the Prometheus data source you added earlier.
  Click "Import".

9. Verify Monitoring

- View Metrics in Prometheus:
  Use the Prometheus web UI to query metrics.
  Example query: up to see if all nodes are up.
- View Dashboards in Grafana:
  Navigate to the imported dashboard.
  Verify that metrics and graphs are displayed correctly.
