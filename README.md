# Deploy EKS cluster with one node group using Terraform

### AWS EKS CLuster

Amazon Elastic Kubernetes Service (Amazon EKS) is a managed service that you can use to run Kubernetes on AWS without needing to install, operate, and maintain your own Kubernetes control plane or nodes. Kubernetes is an open-source system for automating the deployment, scaling, and management of containerized applications. AWS EKS helps you provide highly available and secure clusters and automates key tasks such as patching, node provisioning, and updates.

![1](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/1.png)
![2](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/2.png)

### Terraform is used to provison both EKS kubernetes Infrastructure & Kubernetes app

Terraform is a free and open-source infrastructure as code (IAC) that can help to automate the deployment, configuration, and management of the remote servers. Terraform can manage both existing service providers and custom in-house solutions.

![3](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/3.png)



This terraform github repo brings up EKS Cluster with following properties
* Create the Kubernetes cluster with 3 private subnets in 3 availability zones
* Create 3 public subnets for bastion hosts
* One bastion host for direct access 


**Prerequisites:**

* AWS Account
* Basic understanding of AWS, Terraform & Kubernetes
* GitHub Account

# Part 1: Terraform scripts for the Kubernetes cluster.

**Step 1:  Create `.tf` file for storing environment variables**

* Create `variables.tf` file and add below content in it
  ```
  variable "region" {
    description = "AWS region"
    type        = string
    default     = "us-west-2"
  }
  ```

**Step 2:  Create `.tf` file for storing providers : AWS & Kubernetes**

* Create `providers.tf` file and add below content in it
  ```
  provider "kubernetes" {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }

  provider "aws" {
    region                   = var.region
    shared_credentials_files = ["~/.aws/credentials"]
    profile                  = "vscode-user"
  }

  data "aws_availability_zones" "available" {}

  locals {
    cluster_name = "staging-eks-${random_string.suffix.result}"
  }
  ```
 

**Step 3:- Create .tf file for AWS VPC**

* Create `vpc.tf` file for VPC and add below content in it

  ```
  module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "3.14.2"

    name = "staging-vpc"

    cidr = "10.0.0.0/16"
    azs  = slice(data.aws_availability_zones.available.names, 0, 3)

    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

    enable_nat_gateway   = true
    single_nat_gateway   = true
    enable_dns_hostnames = true

    public_subnet_tags = {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                      = 1
    }

    private_subnet_tags = {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"             = 1
    }
  }
  ```
* using the AWS VPC module for VPC creation
* The above code will create the AWS VPC of `10.0.0.0/16` CIDR range in `us-west-2` region
* The VPC will have 3 private subnets : ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
* The VPC will have 3 public subnets : ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
* `data "aws_availability_zones"` `"azs"` will provide the list of availability zone for the `us-west-2` region


**Step 4:- Create .tf file for AWS Security Group**

* Create `security.tf` file for AWS Security Group and add below content in it

  ```
  resource "aws_security_group" "node_group_one" {
    name_prefix = "node_group_one"
    vpc_id      = module.vpc.vpc_id

    ingress {
      from_port = 22
      to_port   = 22
      protocol  = "tcp"

      cidr_blocks = [
        "10.0.0.0/8",
      ]
    }
  }

  resource "aws_security_group" "node_group_two" {
    name_prefix = "node_group_two"
    vpc_id      = module.vpc.vpc_id
  
    ingress {
      from_port = 22
      to_port   = 22
      protocol  = "tcp"
  
      cidr_blocks = [
        "192.168.0.0/16",
      ]
    }
  }
  ```
  
* creating 2 security groups for 2 worker node group - But enabling node_group_one
* We are allowing only 22 port for the SSH connection
* For node_group_one restricting the SSH access for `10.0.0.0/8` CIDR Block
* For node_group_two restricting the SSH access for `192.168.0.0/16` CIDR Block

**Step 5:- Create .tf file for the EKS Cluster**

* Create `eks.tf` file for VPC and add below content in it

  ```
  module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "18.29.0"

    cluster_name    = local.cluster_name
    cluster_version = "1.23"
  
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets
  
  ```
* For EKS Cluster creation we are using the terraform AWS EKS module
* The below code will create 1 worker node groups with the desired capacity of 2 instances of type t3.small
* attaching the recently created security group to the worker node groups

  ```
    eks_managed_node_group_defaults = {
      ami_type = "AL2_x86_64"
  
      attach_cluster_primary_security_group = true
  
      # Disabling and using externally provided security groups
      create_security_group = false
    }
  
    eks_managed_node_groups = {
      one = {
        name = "node-group-1"
  
        instance_types = ["t3.small"]
  
        min_size     = 1
        max_size     = 2
        desired_size = 2
  
        key_name     = aws_key_pair.key_pair.id
  
        pre_bootstrap_user_data = <<-EOT
        echo 'foo bar'
        EOT
  
        vpc_security_group_ids = [
          aws_security_group.node_group_one.id
        ]
      }
    }
  
    node_security_group_tags = {
      "kubernetes.io/cluster/${local.cluster_name}" = null
    }
  }
  ```

**Step 6:- Create .tf file for bastion host**

* Create `data.tf, bastion.tf & key.tf` file and add below content in it

  ```
  data "aws_ami" "aws_ami_free_tier" {
    most_recent = true
    name_regex  = "^amzn2-ami-kernel.*5.10.*x86_64"
    owners      = ["amazon"]
  
    filter {
      name   = "name"
      values = ["amzn2-ami-kernel-5.10-hvm-2.0.20220805.0-x86_64*"]
    }
  
  
    filter {
      name   = "root-device-type"
      values = ["ebs"]
    }
  
    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }
  }

  resource "aws_key_pair" "key_pair" {
    key_name   = "staging_key"
    public_key = file("~/.ssh/vm-public.pub")
  }

  resource "aws_instance" "public-bastion-1" {
    ami                    = data.aws_ami.aws_ami_free_tier.id
    instance_type          = var.instance_type
    key_name               = aws_key_pair.key_pair.id
    vpc_security_group_ids = [aws_security_group.node_group_one.id]
    #subnet_id              = aws_subnet.staging_public_subnet.id
    subnet_id              = module.vpc.private_subnets[0]
  
    root_block_device {
      volume_size = 8
    }
  
    tags = {
      Name = "public-bastion-1"
    }
  }

  ```
* Bastion host created using available free tier AWS Linux EC2 instance
* existing public key is injected to EC2 instance for ssh access



**Step 7:- Create .tf file for outputs for EKS cluster**

* Create `outputs.tf` file and add below content in it

  ```
  output "cluster_id" {
    description = "EKS cluster ID"
    value       = module.eks.cluster_id
  }
  
  output "cluster_endpoint" {
    description = "Endpoint for EKS control plane"
    value       = module.eks.cluster_endpoint
  }
  
  output "cluster_security_group_id" {
    description = "Security group ids attached to the cluster control plane"
    value       = module.eks.cluster_security_group_id
  }
  
  output "region" {
    description = "AWS region"
    value       = var.region
  }
  
  output "cluster_name" {
    description = "Kubernetes Cluster Name"
    value       = local.cluster_name
  }
  ```

* output the name of cluster, region & expose the endpoint of our cluster.


**Step 8:- Store our code to GitHub Repository**

* store the code in the GitHub repository

![4](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/4.png)

**Step 9:- Initialize the working directory**

* Run `terraform init` command in the working directory, to download all the necessary providers and the modules

**Step 10:- Create a terraform plan**

* Run `terraform plan` command in the working directory, to display the execution plan

  ```
  Plan: 52 to add, 0 to change, 0 to destroy.
  Changes to Outputs:
  + cluster_endpoint          = (known after apply)
  + cluster_id                = (known after apply)
  + cluster_name              = (known after apply)
  + cluster_security_group_id = (known after apply)
  + region                    = "us-west-2"
  ```
  
**Step 11:- Create the cluster on AWS**

* Run `terraform apply` command in the working directory. This will create the Kubernetes EKS cluster on AWS
* Terraform will create the below resources on AWS

* VPC
* Route Table
* IAM Role
* NAT Gateway
* Security Group
* Public & Private Subnets
* EKS Cluster

**Step 12:- Check output of terraform apply**

* Output for `terraform plan` command 

  ```
  $ terraform output
  cluster_endpoint = "https://1730979C8ADA4FCCA1637AF003E7BD2B.gr7.us-west-2.eks.amazonaws.com"
  cluster_id = "staging-eks-q451u04b"
  cluster_name = "staging-eks-q451u04b"
  cluster_security_group_id = "sg-0ffa5cc18b828f74f"
  region = "us-west-2
  ```

**Step 13:- Verify the EKS resources on AWS**

* Navigate to your AWS account and verify the resources

1. EKS Cluster:
![5](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/5.png)

2. Auto Scaling Groups:
![6](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/6.png)

3. EC2 Instances:
![7](https://github.com/bijubayarea/test-terraform-eks-cluster/blob/main/images/7.png)

* Kubernetes cluster is ready 
* Next step is deploying kubernetes applications using a different terraform repository : [Deploy K8s NGINX Application](https://github.com/bijubayarea/test-terraform-deploy-nginx-kubernetes-eks)


**Step 14:- Set kubeconfig to access EKS kubernetes cluster using kubectl**

* retrieve the access credentials for your cluster from output and configure kubectl

  ```
  aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)

  ```


**Step 15:- Access EKS cluster using kubectl**

* Check nodes in K8s cluster

  ```
  $ kubectl get nodes
  NAME                                       STATUS   ROLES    AGE     VERSION
  ip-10-0-1-118.us-west-2.compute.internal   Ready    <none>   6h52m   v1.23.9-eks-ba74326
  ip-10-0-2-251.us-west-2.compute.internal   Ready    <none>   6h52m   v1.23.9-eks-ba74326

  ```
