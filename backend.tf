terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "bijubayarea-s3-remote-backend-deadbeef"
    dynamodb_table = "terraform-state-lock-dynamo"
    key            = "test-terraform-eks-cluster/terraform.tfstate"
    region         = "us-west-2"
  }

  ## ...
}