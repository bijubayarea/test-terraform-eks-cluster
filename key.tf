resource "aws_key_pair" "key_pair" {
  key_name   = "staging_key"
  public_key = file("~/.ssh/vm-public.pub")
}