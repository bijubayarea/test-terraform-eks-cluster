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