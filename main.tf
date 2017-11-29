provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 1.0"
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

# Primary hosted zone
data "aws_route53_zone" "public" {
  name         = "${var.domain}"
  private_zone = false
}

# Zone for a subdomain
resource "aws_route53_zone" "foo" {
  name = "foo.${var.domain}"
}

# Delegates queries from primary zone to the zone for foo.<domain>
resource "aws_route53_record" "foo_delegation" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "foo.${var.domain}"
  type    = "NS"
  ttl     = "86400"
  records = ["${aws_route53_zone.foo.name_servers}"]
}

# Internal hosted zone, associated with the VPC
resource "aws_route53_zone" "internal_zone" {
  name   = "internal.${var.domain}"
  vpc_id = "${aws_vpc.internal_vpc.id}"
}

# This record will be resolved via the public DNS zone - my-host.foo.<domain>
resource "aws_route53_record" "public_record" {
  zone_id = "${aws_route53_zone.foo.zone_id}"
  name    = "webserver"
  type    = "A"
  ttl     = "300"
  records = ["1.2.3.4"]
}

# This record will not be visible inside the VPC - it is masked by the internal zone
resource "aws_route53_record" "masked_record" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "some-host.internal"
  type    = "A"
  ttl     = "300"
  records = ["1.2.3.5"]
}

# This record will be resolved via the private hosted zone
resource "aws_route53_record" "internal_record" {
  zone_id = "${aws_route53_zone.internal_zone.zone_id}"
  name    = "some-db"
  type    = "A"
  ttl     = "300"
  records = ["10.0.0.1"]
}

# VPC, subnet, etc. resources for testing
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

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.internal_vpc.id}"
}

resource "aws_route" "igw_route" {
  route_table_id         = "${aws_vpc.internal_vpc.default_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

# Test instance to test name resolution inside the VPC
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
