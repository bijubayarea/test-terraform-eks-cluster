resource "aws_instance" "public-bastion-1" {
  ami                    = data.aws_ami.aws_ami_free_tier.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.key_pair.id
  vpc_security_group_ids = [aws_security_group.node_group_one.id]
  # subnet_id              = aws_subnet.staging_public_subnet.id
  subnet_id = module.vpc.private_subnets[0]
  # user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "public-bastion-1"
  }
}