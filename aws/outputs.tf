# General
output "_lab_id" {
  description = "a unique Lab Id generated when creating an empty QuickLab."
  value       = try(local.uid, null)
}
output "_lab_resource_group" {
  description = "the Group containing all AWS resources associated wth this Lab Id."
  value       = try(aws_resourcegroups_group.this.name, null)
}


# AWS
output "aws_caller" {
  description = "AWS IAM principal"
  value       = try(data.aws_caller_identity.current.arn, null)
}
output "aws_region" {
  description = "AWS Region"
  value       = try(data.aws_region.current.name, null)
}


# Module: Network
output "network_name" {
  description = "The name of the network."
  value       = try(module.network["${local.uid}"].vpc.tags_all.Name, null)
}
output "network_id" {
  description = " VPC Id"
  value       = try(module.network["${local.uid}"].vpc.id, null)
}
output "network_keyfile" {
  description = "the filepath of the Quicklab network's keypair"
  value       = try("${module.network["${local.uid}"].key_filename}", null)
}


# Module: Bastion
output "bastion_id" {
  description = "EC2 instance id"
  value       = try(module.bastion["${local.uid}"].instance_id, null)
}
output "bastion_known_hosts" {
  description = "add bastion entry to known_hosts with this command"
  value       = try("ssh-keyscan -t ed25519 ${module.bastion["${local.uid}"].public_dns} >> ~/.ssh/known_hosts", null)
}
output "bastion_connect" {
  description = "SSH to instance using this command"
  value       = try("ssh -i '${module.network["${local.uid}"].key_filename}' ec2-user@${module.bastion["${local.uid}"].public_dns}", null)
}
output "bastion_proxyjump_config" {
  description = "the SSH config file that references the the QuickLab Bastion"
  value       = try(module.bastion["${local.uid}"].ssh_config, null)
}


# Module: Cluster
output "cluster_name" {
  description = "EKS cluster ID"
  value       = try(module.cluster["${local.uid}"].cluster.name, null)
}
output "cluster_kubeconfig" {
  description = "add quicklab kubeconfig to $KUBECONFIG path list with this command"
  value       = try(module.cluster["${local.uid}"].kubeconfig, null)
}


# Module: Sumo
output "sumo_caller" {
  description = "Sumo Logic environment / Org ID / AccessId"
  value       = var.sumo_accessid != "unspecified" || var.sumo_accesskey != "unspecified" ? "${data.sumologic_caller_identity.current.environment}/${var.sumo_org}/${data.sumologic_caller_identity.current.access_id}" : tostring(null)
}
output "sumo_cluster_rum_traces_url" {
  description = "the Sumo Logic RUM Traces Source URL"
  value       = try(module.sumo["${local.uid}"].rum_traces_url, null)
}


/*
output "network_priv_subnet_a" {
  description = "network private subnet AZ a"
  value       = module.network["${local.uid}"].private_subnet_a
}
output "network_priv_subnet_b" {
  description = "network private subnet AZ b"
  value       = module.network["${local.uid}"].private_subnet_b
}
output "network_pub_subnets" {
  description = "network public subnet IDs"
  value       = try([module.network["${local.uid}"].public_subnet_a, module.network["${local.uid}"].public_subnet_b], null)
}
output "network_priv_subnets" {
  description = "network private subnet IDs"
  value       = try([module.network["${local.uid}"].private_subnet_a, module.network["${local.uid}"].private_subnet_b], null)
}
output "network_ssh_keyname" {
  description = "the name of the SSH keypair for the QuickLab VPC"
  value       = try(module.network["${local.uid}"].ssh_key.key_name, null)
}

*/
