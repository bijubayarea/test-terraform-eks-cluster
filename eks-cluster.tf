module "eks" {
  source = "terraform-aws-modules/eks/aws"
  #version = "18.26.6"
  version = "18.29.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.23"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type      = "AL2_x86_64"
    capacity_type = "SPOT"

    attach_cluster_primary_security_group = true

    # Disabling and using externally provided security groups
    create_security_group = false
  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]
      #instance_types = ["t2.micro"]

      min_size     = 1
      max_size     = 2
      desired_size = 2


      key_name = aws_key_pair.key_pair.id

      pre_bootstrap_user_data = <<-EOT
      echo 'foo bar'
      EOT

      vpc_security_group_ids = [
        aws_security_group.node_group_one.id
      ]
    }
    /*
    two = {
      name = "node-group-2"

      #instance_types = ["t3.medium"]
      instance_types = ["t2.micro"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

      pre_bootstrap_user_data = <<-EOT
      echo 'foo bar'
      EOT

      vpc_security_group_ids = [
        aws_security_group.node_group_two.id
      ]
    } */
  }

  node_security_group_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = null
  }

}
