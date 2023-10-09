# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


output "vpc" {
  description = "The ID of the VPC"
  value       = aws_vpc.this
}
output "vpc_name" {
  description = "The name of the VPC"
  value       = aws_vpc.this.tags_all.Name
}
output "eip" {
  description = "the Nat Gateway's Elastic IP"
  value       = aws_eip.ngw
}
output "ssh_key" {
  description = "Lab SSH Key used to connect to EC2 instances"
  value       = aws_key_pair.ssh
}
output "key_filename" {
  description = "Lab SSH Key local file name"
  value       = local_sensitive_file.kp.filename
}
output "pl_vpc" {
  description = "ID of VPC managed prefix list"
  value       = aws_ec2_managed_prefix_list.vpc
}
output "pl_remoteaccess" {
  description = "ID of Remote Access managed prefix list"
  value       = aws_ec2_managed_prefix_list.remote_access
}
output "public_subnet_b" {
  description = "ID of public subnet b"
  value       = aws_subnet.public_b.id
}


# Used in "bastion" module
output "public_subnet_a" {
  description = "ID of public subnet a"
  value       = aws_subnet.public_a.id
}
output "subnet_public_a_az" {
  description = "Name of AZ for public subnet a"
  value       = aws_subnet.public_a.availability_zone
}
output "sg_remoteaccess_ssh_id" {
  description = "the id of the Network's remoteaccess_ssh security group"
  value       = aws_security_group.remoteaccess_ssh.id
}
output "sg_remoteaccess_rdp_id" {
  description = "the id of the Network's remoteaccess_rdp security group"
  value       = aws_security_group.remoteaccess_rdp.id
}


# Used in "cluster" module
output "private_subnet_a" {
  description = "private subnet a ID"
  value       = aws_subnet.private_a.id
}
output "private_subnet_b" {
  description = "private subnet b ID"
  value       = aws_subnet.private_b.id
}
output "sg_remote_ssh" {
  description = ""
  value       = aws_security_group.remoteaccess_ssh.id
}


# Used in "sumo" module
output "cwlog_group_flowlogs" {
  description = "the ID of the CloudWatch Log Group for QuickLab VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flowlogs.name
}

