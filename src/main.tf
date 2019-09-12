###############################################################################
# Setup
###############################################################################
provider "aws" {
  version = "~> 2.23"
  region  = "us-east-1"
}

provider "null" {
  version = "~> 2.1"
}

terraform {
  backend "s3" {
    bucket         = "com.iac-example"
    key            = "salt-orchestration"
    region         = "us-east-1"
    dynamodb_table = "terraform-statelock"
  }
}

provider "external" {
  version = "~> 1.2"
}

###############################################################################
# Local Variables
###############################################################################
locals {
  ami_name                  = "linux-centos-7-1810-aee8db4c"
  app_domains               = [
    "swarm-apps.com"
  ]
  availability_zones        = [
    "us-east-1a",
    "us-east-1b"
  ]
  description_tag           = "Managed By Terraform"
  group_tag                 = "Network Infrastructure"
  primary_domain            = "iac-example.com"
  saltmaster_instance_count = 1
  saltmaster_instance_type  = "t2.micro"
  saltmaster_instance_name  = "salt"
  ssh_private_key           = "${base64decode(var.ssh_private_key)}"
  starting_hostnum          = 4
  vpc_cidr_block            = "172.32.0.0/16"
  whitelist_cidrs           = [
    "${local.vpc_cidr_block}"
  ]
}

###############################################################################
# Shared Data Sources
###############################################################################
data "aws_ami" "default" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${local.ami_name}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

data "aws_vpc" "default" {
  cidr_block = "${local.vpc_cidr_block}"
}

data "aws_subnet" "default" {
  count = "${length(local.availability_zones)}"

  availability_zone = "${local.availability_zones[count.index]}"
  filter {
    name   = "tag:Scope"
    values = ["private"]       # insert value here
  }
}

data "aws_route53_zone" "default" {
  name = "${local.primary_domain}."
}

###############################################################################
# Saltmaster
###############################################################################
module "saltmaster" {
  source  = "./modules/saltmaster"

  ami                         = "${data.aws_ami.default.id}"
  associate_public_ip_address = true
  availability_zones          = "${local.availability_zones}"
  description_tag             = "${local.description_tag}"
  domain                      = "${local.primary_domain}"
  group_tag                   = "${local.group_tag}"
  instance_count              = "${local.saltmaster_instance_count}"
  instance_type               = "${local.saltmaster_instance_type}"
  name_tag                    = "${local.saltmaster_instance_name}-${terraform.workspace}"
  ssh_username                = "${var.ssh_username}"
  ssh_private_key             = "${local.ssh_private_key}"
  starting_hostnum            = "${local.starting_hostnum}"
  subnet_ids                  = "${data.aws_subnet.default.*.id}"
  subnet_cidrs                = "${data.aws_subnet.default.*.cidr_block}"
  vpc_id                      = "${data.aws_vpc.default.id}"
  whitelist_cidrs             = "${local.whitelist_cidrs}"
  zone_id                     = "${data.aws_route53_zone.default.id}"
}
