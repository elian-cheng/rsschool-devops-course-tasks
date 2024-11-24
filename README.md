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
- **ecr.tf**: ECR role && policy definition

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

Check the cloud init logs:

```bash
cat /var/log/cloud-init-output.log

```

6. **Copy the k3s.yaml File to your local machine:**

```bash
scp -i path/to/your/private_key.pem ubuntu@<k3s_master_public_ip>:/etc/rancher/k3s/k3s.yaml /path/to/local/directory/k3s.yaml
```

or connected to the instance already:

```bash
sudo cp /etc/rancher/k3s/k3s.yaml /path/to/local/directory/k3s.yaml
```

7. **Set the KUBECONFIG Environment Variable on your local machine and verify the cluster (in another terminal, parallel to open SSH tunnel):**

```bash
export KUBECONFIG=/path/to/local/directory/k3s.yaml
```

OR merge k3s.yaml with Existing Kubeconfig (for long use only):

```bash
KUBECONFIG=~/.kube/config:/path/to/k3s.yaml kubectl config view --merge --flatten > ~/.kube/config
```

access from the local pc via SSH tunnel:

```bash
ssh -i /path/to/your/key.pem -L 6443:localhost:6443 ubuntu@<EC2_PUBLIC_IP>
```

8. **Check the Status of the pods & services:**

```bash
kubectl get pods -A
```

```bash
kubectl get svc -A
```

9. **Login to SonarQube and config:**
   You can access the SonarQube using the public IP of your EC2 instance and the specified load balancer port 9000 (default for SonarQube):

```bash
echo "http://<ec2-instance-public-ip>:9000"
```

Open a web browser and navigate to http://<ec2-instance-public-ip>:9000. You should see the login form. Default login credentials are: login - admin, pw - admin.

After login you need to create a project and generate a project token, which you need to provide in your Jenkinsfile for the pipeline.

9. **Login to Jenkins and config:**
   You can access the Jenkins using the public IP of your EC2 instance and the specified load balancer port 8080 (default for Jenkins):

```bash
echo "http://<ec2-instance-public-ip>:9000"
```

Retrieve the Jenkins admin password:

```bash
kubectl exec --namespace jenkins -it svc/my-jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password
```

Or get it from EC2 user_data script output:

```bash
cat /var/log/cloud-init-output.log

```

Open a web browser and navigate to http://<ec2-instance-public-ip>:9000. You should see the login form. Default login credentials are: login - admin, pw - retrieved from the jenkins file.

After login you need to install plugins: Email Extension Plugin (for notifications), SonarQube Scanner for Jenkins, Amazon EC2 plugin (to get custom AWS credentials), Generic Webhook Trigger plugin (for the trigger on pushes to the other repository with app and Dockerfile).

Then you need to create credentials for the email access (also a google app password in google console, if needed) and aws credentials for the pipeline. Make sure that AWS credentials for this user (role) in IAM include permission to access EC2ContainerRegistry.

For the detailed screenshots check [PR](https://github.com/elian-cheng/rsschool-devops-course-tasks/pull/9)

10. **Setup the webhook trigger**
    In github settings in other repo (docker application):
    Settings > Webhooks > Add webhook > Payload URL ↓

```bash
http://<ec2-instance-public-ip>:8080/generic-webhook-trigger/invoke?<token-name>
```

11. **Jenkins job config**
    Create a new pipeline job, and config build triggers to use generic webhook trigger, add a token name

12. **Start the Jenkins job**:
    You can start the job manually or it would start automatically on push to the app repo.
    By default SHOULD_PUSH_TO_ECR is set to false in Jenkins file, so you can manually override it
    by using "Build with Parameters" option in Jenkins and set it to true, so it would also
    push the image to ECR and deploy to the Kubernetes cluster with Helm.
