
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
}

provider "aws" {
  #shared_config_files      = ["/Users/tf_user/.aws/conf"]
  region                   = var.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "vscode-user"
}