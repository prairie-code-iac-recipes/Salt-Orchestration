locals {
  security_group_rules = [
    {
      type        = "ingress"
      from_port   = "22"
      to_port     = "22"
      protocol    = "tcp"
      cidr_blocks = "${var.whitelist_cidrs}"
    },
    {
      type        = "ingress"
      from_port   = "4505"
      to_port     = "4506"
      protocol    = "tcp"
      cidr_blocks = "${var.whitelist_cidrs}"
    },
    {
      type        = "egress"
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# #############################################################################
# The host offset external data provider is used to calculate host number
# offsets under the assumption that instances will be assigned to availability
# zone-specific subnets in a round-robin fashion.  The offset calculated will
# be added to some starting host number reflecting the first unassigned host
# number.
#
# Example:
# Starting Host Number: 4
# AZ #1 Subnet Host Numbers: Host 1 Assigned 4, Host 3 Assigned 5, etc...
# AZ #2 Subnet Host Numbers: Host 2 Assigned 4, Host 4 Assigned 5, etc...
# #############################################################################
data "external" "host_offset" {
  program       = ["bash", "${path.module}/scripts/host-offset.sh"]

  query = {
    subnet_count                       = "${length(var.subnet_cidrs)}"
    instance_count                     = "${var.instance_count}"
  }
}

###############################################################################
# Security Group
###############################################################################
resource "aws_security_group" "default" {
  name                   = "${var.name_tag}"
  vpc_id                 = "${var.vpc_id}"

  tags = {
    Group                = "${var.group_tag}"
    Description          = "${var.description_tag}"
  }
}

resource "aws_security_group_rule" "default" {
  count             = "${length(local.security_group_rules)}"

  type              = "${local.security_group_rules[count.index]["type"]}"
  from_port         = "${local.security_group_rules[count.index]["from_port"]}"
  to_port           = "${local.security_group_rules[count.index]["to_port"]}"
  protocol          = "${local.security_group_rules[count.index]["protocol"]}"
  cidr_blocks       = "${local.security_group_rules[count.index]["cidr_blocks"]}"

  security_group_id = "${aws_security_group.default.id}"
}

###############################################################################
# Instances
###############################################################################
resource "aws_instance" "default" {
  count                                = "${var.instance_count}"

  ami                                  = "${var.ami}"
  associate_public_ip_address          = "${var.associate_public_ip_address}"
  availability_zone                    = "${element(var.availability_zones, count.index + 1 % length(var.availability_zones))}"
  instance_type                        = "${var.instance_type}"
  private_ip                           = "${cidrhost(element(var.subnet_cidrs, count.index + 1 % length(var.subnet_cidrs)), lookup(data.external.host_offset.result, count.index) + var.starting_hostnum)}"
  subnet_id                            = "${element(var.subnet_ids, count.index + 1 % length(var.subnet_ids))}"
  vpc_security_group_ids               = ["${aws_security_group.default.id}"]

  tenancy                              = "default"
  instance_initiated_shutdown_behavior = "stop"

  tags = {
    Name            = "${format("${var.name_tag}-%02d", count.index + 1)}"
    Description     = "${var.description_tag}"
    Group           = "${var.group_tag}"
  }
}

###############################################################################
# DNS Records - External Connectivity is via SSH and Restricted
###############################################################################
resource "aws_route53_health_check" "default" {
  count = "${length(aws_instance.default.*.public_ip)}"

  ip_address        = "${element(aws_instance.default.*.public_ip, count.index)}"
  port              = 22
  type              = "TCP"
  failure_threshold = "5"
  request_interval  = "30"
}

resource "aws_route53_record" "default" {
  count           = "${length(aws_instance.default.*.public_ip)}"

  zone_id         = "${var.zone_id}"
  name            = "${var.name_tag}.${var.domain}"
  type            = "A"
  ttl             = "30"
  health_check_id = "${element(aws_route53_health_check.default.*.id, count.index)}"

  weighted_routing_policy {
    weight = 10
  }
  set_identifier  = "${format("${var.name_tag}.${var.domain}.%02d", count.index+1)}"

  records = [
    "${element(aws_instance.default.*.public_ip, count.index)}"
  ]
}

resource "aws_route53_record" "unique_instance_dns_names" {
  count   = "${length(aws_instance.default.*.public_ip)}"

  zone_id = "${var.zone_id}"
  name    = "${format("${var.name_tag}-%02d", count.index + 1)}.${var.domain}"
  type    = "A"
  ttl     = "30"

  records = [
    "${element(aws_instance.default.*.public_ip, count.index)}"
  ]
}

resource "aws_route53_record" "internal" {
  count   = "${length(aws_instance.default.*.private_ip) > 0 ? 1 : 0}"

  zone_id = "${var.zone_id}"
  name    = "${var.name_tag}-internal.${var.domain}"
  type    = "A"
  ttl     = "30"

  records = [
    "${aws_instance.default[0].private_ip}"
  ]
}

###############################################################################
# Configure Salt
###############################################################################
# # Migrate Top File
module "migrate_top" {
  source = "git@gitlab.com:prairie-code-iac-recipes/salt-configuration.git//src/modules/migrate_top"

  hosts           = "${aws_instance.default.*.public_ip}"
  ssh_username    = "${var.ssh_username}"
  ssh_private_key = "${var.ssh_private_key}"
}

# # Migrate State Files
module "migrate_all_states" {
  source = "git@gitlab.com:prairie-code-iac-recipes/salt-configuration.git//src/modules/migrate_all_states"

  hosts           = "${aws_instance.default.*.public_ip}"
  ssh_username    = "${var.ssh_username}"
  ssh_private_key = "${var.ssh_private_key}"
}

# Install Salt and Configure Instances as Both Master and Minion
resource "null_resource" "bootstrap" {
  count = "${length(aws_instance.default.*.public_ip)}"

  connection {
    type        = "ssh"
    user        = "${var.ssh_username}"
    private_key = "${var.ssh_private_key}"
    host        = "${aws_instance.default.*.public_ip[count.index]}"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "curl -o /tmp/bootstrap-salt.sh -L https://bootstrap.saltstack.com",
      "chmod +x /tmp/bootstrap-salt.sh",
      "sudo /tmp/bootstrap-salt.sh -M -A 127.0.0.1",
      "rm /tmp/bootstrap-salt.sh"
    ]
  }

  depends_on = [
    module.migrate_top,
    module.migrate_all_states
  ]
}

# Accept Key
resource "null_resource" "accept_key" {
  count = "${length(aws_instance.default.*.public_ip)}"

  connection {
    type        = "ssh"
    user        = "${var.ssh_username}"
    private_key = "${var.ssh_private_key}"
    host        = "${aws_instance.default.*.public_ip[count.index]}"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eou pipefail",
      "sleep 60s",
      "sudo salt-key -A -y"
    ]
  }

  depends_on = [
    module.migrate_top,
    module.migrate_all_states
  ]
}

