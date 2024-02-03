# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


output "instance_id" {
  description = "ID of the EC2 Instance"
  value       = aws_instance.this.id
}
output "bastion_az" {
  description = "AZ of public subnet"
  value       = aws_instance.this.availability_zone
}

output "public_dns" {
  description = "public DNS name of the EC2 Instance"
  value       = aws_instance.this.public_dns
}
output "bastion_role" {
  description = "AWS IAM Role for the Host Profile of the EC2 Instance"
  value       = aws_iam_role.bastion
}
output "ssh_config" {
  description = "the SSH config file that references the the QuickLab Bastion"
  value       = local_file.ssh_config.filename
}

# used in "cluster" module
output "bastion_sg" {
  description = "Bastion default Security Group"
  value       = aws_security_group.bastion.id
}
