provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 1.0"
}

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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_route53_zone" "public_zone" {
  name         = "${var.domain}"
  private_zone = false
}

resource "aws_route53_zone" "internal_zone" {
  name   = "internal.${var.domain}"
  vpc_id = "${aws_vpc.internal_vpc.id}"
}

// this record will be resolved via the public DNS zone
resource "aws_route53_record" "public_record" {
  zone_id = "${data.aws_route53_zone.public_zone.zone_id}"
  name    = "foo"
  type    = "A"
  ttl     = "300"
  records = ["1.2.3.4"]
}

// this records won't be visible inside the VPC since it's masked and R53 won't delegate
resource "aws_route53_record" "masked_record" {
  zone_id = "${data.aws_route53_zone.public_zone.zone_id}"
  name    = "bar.internal"
  type    = "A"
  ttl     = "300"
  records = ["1.2.3.5"]
}

// this record will be resolved via the private hosted zone
resource "aws_route53_record" "internal_record" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "foo"
  type    = "A"
  ttl     = "300"
  records = ["10.0.0.1"]
}

resource "aws_vpc" "internal_vpc" {
  cidr_block = "${var.internal_vpc_cidr}"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Demo VPC"
  }
}

resource "aws_subnet" "internal_vpc_sn" {
  vpc_id     = "${aws_vpc.internal_vpc.id}"
  cidr_block = "${var.internal_vpc_sn_cidr}"
}

# resource "aws_route53_zone_association" "internal_vpc_assoc" {
#   zone_id = "${aws_route53_zone.internal_zone.zone_id}"
#   vpc_id  = "${aws_vpc.internal_vpc.id}"
# }

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.internal_vpc.id}"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.internal_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "hello" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  key_name                    = "${var.key_name}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.internal_vpc_sn.id}"
  associate_public_ip_address = true
  vpc_security_group_ids      = ["${aws_security_group.allow_ssh.id}"]

  tags = {
    Name = "route53-demo"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = "${aws_vpc.internal_vpc.default_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

output "public_dns" {
  value = "${aws_instance.hello.public_dns}"
}

output "public_ip" {
  value = "${aws_instance.hello.public_ip}"
}
