resource "aws_instance" "public-bastion-1" {
  ami                         = data.aws_ami.aws_ami_free_tier.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.key_pair.id
  vpc_security_group_ids      = [aws_security_group.staging_public_sg.id]
  subnet_id                   = module.vpc.public_subnets[0]
  # user_data                   = file("userdata.tpl")
  associate_public_ip_address = "true"

  root_block_device {
    volume_size = 8
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/vm-key-pair.pem")
    host        = self.public_ip
  }

  # SAVE MONEY by preventing kubectl download
  # This provisioner run only when resource is CREATED
  #provisioner "remote-exec" {
  #  #continue on failure, don't TAINT the resource EC2
  #  on_failure = continue
  #
  #  inline = [
  #    "curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.7/2022-06-29/bin/linux/amd64/kubectl",
  #    "chmod +x ./kubectl",
  #    "mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin",
  #    "echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc",
  #  
  #  ]
  #}

  # Copies the privatekey file to bastion-ec2
  # Don't do this on production systems.
  provisioner "file" {
    source      = "~/.ssh/vm-key-pair.pem"
    destination = "/home/ec2-user/vm-key-pair.pem"
  }


  tags = {
    Name = "public-bastion-1"
  }
}


resource "null_resource" "kubeconfig-context" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig  --name ${local.cluster_name} --kubeconfig ~/.kube/config"
  }
}