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

4. **Get the Public IP of Your K3s Master Node**:

   - Note the public IP address of your K3s master node. You can find this in your AWS EC2 dashboard under instances.

5. **SSH into the K3s Master Node**:

```bash
ssh -i path/to/your/private_key.pem ubuntu@<k3s_master_public_ip>

```

Verify the K3s Installation:

```bash
sudo systemctl status k3s

```

6. **Copy the k3s.yaml File to your local machine:**

```bash
scp -i path/to/your/private_key.pem ubuntu@<k3s_master_public_ip>:/etc/rancher/k3s/k3s.yaml /path/to/local/directory/k3s.yaml
```

7. **Set the KUBECONFIG Environment Variable on your local machine and verify the cluster (in another terminal, parallel to open SSH tunnel):**

```bash
export KUBECONFIG=/path/to/local/directory/k3s.yaml
```

8. **Verify the Cluster and Jenkins:**

```bash
kubectl get nodes
```

```bash
kubectl get pods -n jenkins
```

9. **Access Jenkins:**
   Since we have set the service type to LoadBalancer, we should be able to access Jenkins via the public IP of our master node.
   Retrieve the service details to get the external IP:

```bash
kubectl get svc -n jenkins
```

Open a web browser and navigate to http://<master_node_public_ip>:8080. You should see the Jenkins setup wizard.

10. **Unlock Jenkins:**
    You’ll need the initial admin password to unlock Jenkins. Retrieve it by running:

```bash
    kubectl exec -n jenkins <jenkins-pod-name> -- cat /var/jenkins_home/secrets/initialAdminPassword
```

Copy the password and paste it into the Jenkins setup wizard to unlock Jenkins.

11. **Create a Freestyle Project:**
    Follow the setup wizard to install recommended plugins.
    Create a new Freestyle project:

- Name it something like "HelloWorld".
- In the build section, add an "Execute shell" build step with the following command:

```bash
echo "Hello world"
```

- Save the project and run it.

12. **Verify the Build Output:**
    After running the job, check the console output to ensure it shows "Hello world".

13. **Check Persistent Volume Configuration:**
    Ensure that the persistent volume (PV) and persistent volume claim (PVC) were created successfully:

```bash
kubectl get pv
kubectl get pvc -n jenkins
```

14. **Verify your Helm installation by deploying and removing the Nginx chart from Bitnami:**
    First, install the Nginx chart using Helm. You can run the following command to deploy the Nginx server:

```bash
helm install my-nginx oci://registry-1.docker.io/bitnamicharts/nginx
```

Verify the Deployment:

```bash
kubectl get pods
```

Remove the Nginx Chart:

```bash
helm uninstall my-nginx
```

Check that the Nginx resources have been removed:

```bash
kubectl get pods
kubectl get svc
```
