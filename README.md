# vprofile EKS Cluster — Terraform

Minimal Terraform configuration to provision an AWS EKS cluster with a public subnet architecture in `us-east-1`.

---

## Architecture

- VPC `10.0.0.0/16` with 2 public subnets across `us-east-1a` and `us-east-1b`
- Internet Gateway with a single public route table
- EKS cluster with public endpoint access only
- Managed node group: 1x `t3.large` (min=1, max=2) in public subnets
- No private subnets, no NAT Gateways — optimized for cost

---

## File Structure

| File | Description |
|---|---|
| `main.tf` | VPC, subnets, IGW, IAM roles, EKS cluster and node group |
| `variables.tf` | All configurable input parameters |
| `outputs.tf` | Cluster endpoint, name, and ARN |
| `backend.tf` | S3 remote state backend |

---

## Variables

| Name | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region |
| `cluster_name` | `vprofile-eks-cluster` | EKS cluster name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_cidrs` | `["10.0.1.0/24", "10.0.2.0/24"]` | Public subnet CIDRs |
| `availability_zones` | `["us-east-1a", "us-east-1b"]` | Availability zones |
| `node_instance_type` | `t3.large` | Worker node EC2 instance type |
| `node_desired_size` | `1` | Desired number of worker nodes |
| `node_min_size` | `1` | Minimum number of worker nodes |
| `node_max_size` | `2` | Maximum number of worker nodes |
| `public_access_cidrs` | *(required)* | CIDR blocks allowed to access the EKS public API endpoint |

---

## Outputs

| Name | Description |
|---|---|
| `cluster_endpoint` | EKS API server endpoint URL |
| `cluster_name` | Name of the EKS cluster |
| `cluster_arn` | Full ARN of the EKS cluster |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with sufficient permissions
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for interacting with the cluster
- An existing S3 bucket for Terraform remote state

### Required IAM Permissions

The AWS credentials used must have permissions to manage:
- VPC, Subnets, Internet Gateway, Route Tables
- IAM Roles and Policy Attachments
- EKS Clusters and Node Groups
- EC2 instances (for the node group)

---

## Before Running

### 1. Create the S3 backend bucket

The S3 bucket for remote state must exist before running `terraform init`. Create it if it doesn't already exist:

```bash
aws s3api create-bucket \
  --bucket vprofile-eks-tfstate \
  --region us-east-1
```

### 2. Update `backend.tf` with your bucket name

Open `backend.tf` and replace the bucket name if you are using a different one:

```hcl
terraform {
  backend "s3" {
    bucket = "your-actual-bucket-name"
    key    = "eks/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 3. Configure AWS credentials

Ensure your AWS CLI is authenticated:

```bash
aws configure
```

Or export environment variables:

```bash
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>
export AWS_DEFAULT_REGION=us-east-1
```

---

## Deploy

```bash
# Initialise Terraform and configure the backend
terraform init

# Preview the resources to be created
terraform plan

# Apply the configuration
terraform apply
```

Type `yes` when prompted to confirm the apply.

---

## Connect to the Cluster

After a successful `terraform apply`, update your local kubeconfig to connect to the cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name vprofile-eks-cluster
```

Verify the connection:

```bash
kubectl get nodes
```

---

## Overriding Variables

You can override any default variable at apply time without editing files:

```bash
terraform apply \
  -var="node_instance_type=t3.medium" \
  -var="node_max_size=3"
```

Or create a `terraform.tfvars` file:

```hcl
node_instance_type = "t3.medium"
node_max_size      = 3
```

---

## Destroy

To tear down all resources and avoid ongoing charges:

```bash
terraform destroy
```

> **Note:** This will permanently delete the EKS cluster, VPC, subnets, and all associated resources. Ensure any workloads are safely removed beforehand.

---

## IAM Policies Attached

**EKS Cluster Role:**
- `AmazonEKSClusterPolicy`

**EKS Node Group Role:**
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

**EBS CSI Driver Role (`AmazonEKS_EBS_CSI_DriverRole`):**
- `AmazonEBSCSIDriverPolicy`

---

## EBS CSI Driver

The EBS CSI Driver is installed as a managed EKS addon with IRSA (IAM Roles for Service Accounts).

**How it works:**
1. An OIDC provider is associated with the EKS cluster
2. An IAM role is created with a trust policy scoped to the `ebs-csi-controller-sa` service account in the `kube-system` namespace
3. The `AmazonEBSCSIDriverPolicy` is attached to the role
4. The `aws-ebs-csi-driver` addon is enabled — AWS creates the Kubernetes service account automatically

**This enables:**
- Dynamic provisioning of EBS volumes via `PersistentVolumeClaim`
- Use of `StorageClass` with `provisioner: ebs.csi.aws.com`

**Example StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
```

## Install ArgoCD
**Bash**
# Add ArgoCD Helm repo
- `helm repo add argo https://argoproj.github.io/argo-helm`
- `helm repo update`

# Install ArgoCD
- `helm upgrade argocd argo/argo-cd --version 9.5.2 --install --create-namespace -n argocd`

# Wait for ArgoCD server to be ready
- `kubectl rollout status deployment argocd-server -n argocd`

## Create Ingress for ArgoCD
# Get your ACM Certificate ARN:
**Bash**
```
aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[*].{Domain:DomainName, ARN:CertificateArn}" \
  --output table
```
