variable "aws_region" {
  default = "ap-southeast-1"
}

variable "domain" {
  type = "string"
}

variable "internal_vpc_cidr" {
  default = "10.98.0.0/16"
}

variable "internal_vpc_sn_cidr" {
  default = "10.98.1.0/24"
}

variable "key_name" {
  type = "string"
}
