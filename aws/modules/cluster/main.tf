# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


# EKS Cluster 
resource "aws_eks_cluster" "this" {
  name                      = "${var.prefix}-${var.uid}-cluster"
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    # used for the ENIs required for communication between control plane and nodes
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = ["${var.private_subnet_a}", "${var.private_subnet_b}"] # must cover two AZs
    endpoint_private_access = true                                                   # enables pod-to-cluster comms when restricting public access by CIDR
    endpoint_public_access  = true                                                   # default is true
    public_access_cidrs     = var.pl_remoteaccess.entry[*].cidr
  }

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-${local.module}-eks"
    CreatedBy = var.creator
  }

  timeouts {
    create = "30m" # default: 30m
    update = "60m" # default: 60m
    delete = "30m" # default: 15m
  }

  depends_on = [
    aws_cloudwatch_log_group.eks,
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "rm ~/.kube/${self.name}"
  }
}


# EKS Logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.prefix}-${var.uid}-cluster/cluster"
  retention_in_days = 7

  tags = {
    Module = local.module
    Name   = "${var.prefix}-${var.uid}-${local.module}-controlplane"
  }
}


# Kubeconfig

resource "local_file" "dotkube" {
  content  = "this file confirms the exsistence of the path ~/.kube"
  filename = pathexpand("~/.kube/${var.prefix}-pathcheck.txt")
}

resource "null_resource" "kubeconfig" {

  provisioner "local-exec" {
    command = "echo \"$(date) | KUBECONFIG=$${KUBECONFIG}\" > ~/.kube/kubeconfig-original.txt"
  }

  provisioner "local-exec" {
    command = "aws eks --region ${data.aws_region.current.name} update-kubeconfig --kubeconfig ~/.kube/${aws_eks_cluster.this.name} --name ${aws_eks_cluster.this.name} --alias ${aws_eks_cluster.this.name} --user-alias ${aws_eks_cluster.this.name}"
  }

  triggers = {
    new_cluster = aws_eks_cluster.this.id
  }

  depends_on = [
    local_file.dotkube,
    aws_eks_cluster.this
  ]
}


# EKS Node Group
resource "aws_eks_node_group" "this" {
  cluster_name           = aws_eks_cluster.this.name
  node_group_name_prefix = "group-"
  version                = aws_eks_cluster.this.version
  release_version        = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value) # defaults to latest
  node_role_arn          = aws_iam_role.node.arn
  subnet_ids             = [var.private_subnet_a, var.private_subnet_b]
  instance_types         = ["t3.xlarge"]

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  scaling_config {
    desired_size = 2
    min_size     = 0
    max_size     = 6
  }

  update_config {
    max_unavailable_percentage = 100
  }

  /*
  # no remote_access block if using aws_launch_template
  remote_access {
    ec2_ssh_key               = var.ssh_key.key_name
    source_security_group_ids = var.network_sg_remote_ssh != null ? [var.network_sg_remote_ssh] : [aws_security_group.node.id] # ensures list always has an entry to avoid default behavior of opening node SG up to 0.0.0.0/0 when list is empty
  }
  */

  lifecycle {
    ignore_changes = [
      release_version,
      scaling_config[0].desired_size # Allow node autoscaling (outside of tf) without Terraform plan difference
    ]
  }

  depends_on = [
    # aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    # aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    # aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }

}
resource "aws_launch_template" "this" {
  # image_id               = data.aws_ssm_parameter.eks_ami_release_version.value
  # instance_type          = "t3.xlarge"
  name                   = "${var.prefix}-${var.uid}-eks-nodegroup-lt"
  update_default_version = true

  # remote access
  key_name               = var.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.node.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name   = "${aws_eks_cluster.this.name}-eks-node",
      LabId  = var.uid,
      Module = local.module
    }
  }

  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.this.name}" = "owned"
    Module                                               = local.module
    CreatedBy                                            = var.creator
  }
}
/*
resource "aws_autoscaling_group_tag" "name" {
  autoscaling_group_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "Name"
    value               = "${aws_eks_cluster.this.name}-eks-node"
    propagate_at_launch = true
  }

  depends_on = [aws_eks_node_group.this]
}
resource "aws_autoscaling_group_tag" "labid" {
  autoscaling_group_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "LabId"
    value               = var.uid
    propagate_at_launch = true
  }

  depends_on = [aws_eks_node_group.this]
}
resource "aws_autoscaling_group_tag" "module" {
  autoscaling_group_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "Module"
    value               = local.module
    propagate_at_launch = true
  }

  depends_on = [aws_eks_node_group.this]
}
*/

# Security Group: Cluster
resource "aws_security_group" "cluster" {
  name        = "eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc.id

  tags = {
    Component = local.module
    Name      = "${var.vpc.tags_all.Name}-sg-cluster-management"
    CreatedBy = var.creator
  }
}
resource "aws_security_group_rule" "allow_node_https_in" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 443
  type                     = "ingress"
}
resource "aws_security_group_rule" "allow_remoteaccess_https_in" {
  prefix_list_ids   = [var.pl_remoteaccess.id]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  to_port           = 443
  type              = "ingress"
}


# Security Group: Node
resource "aws_security_group" "node" {
  name        = "eks-nodes"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc.id

  tags = {
    Component = local.module
    Name      = "${var.vpc.tags_all.Name}-sg-cluster-node"
    CreatedBy = var.creator
  }

}
resource "aws_security_group_rule" "allow_cluster_https_in" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 443
  type                     = "ingress"
}
resource "aws_security_group_rule" "allow_other_in" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "allow_all_node" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}


# Security Group Rules
resource "aws_security_group_rule" "allow_all_out" {
  for_each = {
    "cluster" = "${aws_security_group.cluster.id}"
    "node"    = "${aws_security_group.node.id}"
  }
  type        = "egress"
  description = "Allow all traffic out (IPv4)" # recreates default AWS SG outbound rule that terraform implicitly deletes
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  # ipv6_cidr_blocks  = ["::/0"]
  security_group_id = each.value
}


# IAM Role: Cluster
resource "aws_iam_role" "cluster" {
  name               = "${var.prefix}-${var.uid}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_trust.json

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "cluster_trust" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}
resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}


# IAM Role: Node
resource "aws_iam_role" "node" {
  name               = "${var.prefix}-${var.uid}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_trust.json

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "node_trust" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}
