output "availability_zones" {
  description = "The availability zones assoiated with the provisioned instances."
  value       = "${aws_instance.default.*.availability_zone}"
  sensitive   = false
}

output "instance_ids" {
  description = "The AWS-assigned identifiers associated with the provisioned instances."
  value       = "${aws_instance.default.*.id}"
  sensitive   = false
}

output "load_balanced_fqdn" {
  description = "This is the fully-qualified domain name shared across all of the provisioned instances."
  value       = "${aws_route53_record.default.*.fqdn}"
}

output "public_ip" {
  description = "Public IP addresses associated with the provisioned instances."
  value       = "${aws_instance.default.*.public_ip}"
  sensitive   = false
}

output "private_ip" {
  description = "Private IP addresses associated with the provisioned instances."
  value       = "${aws_instance.default.*.private_ip}"
  sensitive   = false
}

output "max_hostnum_offset" {
  description = "The largest offset used to assign IP addresses to provisioned instances. This offset may have been used to assign IP addresses to multiple instances if multiple subnets were specified."
  value       = "${lookup(data.external.host_offset.result, "max")}"
  sensitive   = false
}

output "unique_fqdns" {
  description = "Lists the fully-qualified domain names associated with each of the provisioned instances."
  value       = "${aws_route53_record.unique_instance_dns_names.*.fqdn}"
}
