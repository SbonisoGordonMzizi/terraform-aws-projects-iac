variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "techcreate_datacenter"
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/24"
}
