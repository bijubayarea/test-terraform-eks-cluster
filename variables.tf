variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "instance type"
  type        = string
  default     = "t2.micro"
}
