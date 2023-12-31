# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


output "cluster" {
  description = "cluster id"
  value       = aws_eks_cluster.this
}
output "public_access_cidrs" {
  description = "list of CIDRs with public access to the cluster API server endpoint"
  value       = aws_eks_cluster.this.vpc_config[0].public_access_cidrs
}
output "kubeconfig" {
  description = "add quicklab kubeconfig to $KUBECONFIG path list with this command"
  value       = "export KUBECONFIG=$KUBECONFIG:~/.kube/${aws_eks_cluster.this.name}"
}
output "aws_iam_openid_connect_provider_arn" {
  value = aws_iam_openid_connect_provider.cluster.arn
}

