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

/*

output "ssh_known_hosts" {
  description = "add bastion entry to known_hosts with this command"
  value       = "ssh-keyscan -t ed25519 ${aws_instance.this.public_dns} >> ~/.ssh/known_hosts"
}

output "ssh" {
  description = "SSH to instance using this command"
  value       = "ssh -i '${local_sensitive_file.kp.filename}' ec2-user@${aws_instance.this.public_dns}"
}
*/
