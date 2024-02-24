# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.this.version}/amazon-linux-2/recommended/release_version"
}
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
  # url = aws_eks_cluster.this.identity.0.oidc.0.issuer
}
locals {
  module = basename(abspath(path.module))
  policies = {
    AmazonEKSWorkerNodePolicy           = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    AmazonEKS_CNI_Policy                = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    AmazonEBSCSIDriverPolicy            = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
    AWSFaultInjectionSimulatorEKSAccess = "arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorEKSAccess"
  }
  addons = [
    {
      name    = "aws-ebs-csi-driver"
      version = "v1.28.0-eksbuild.1"
    }
    /*
    ,
    {
      name = "snapshot-controller"
      version = "v6.3.2-eksbuild.1"
    }
    {
      name    = "kube-proxy"
      version = "v1.29.1-eksbuild.2"
    }
    {
      name    = "coredns"
      version = "v1.11.1-eksbuild.6"
    },
    {
      name    = "vpc-cni"
      version = "v1.16.3-eksbuild.2"
    },
    {
      name = "aws-mountpoint-s3-csi-driver"
      version = "v1.3.1-eksbuild.1"
    }
    {
      name = "eks-pod-identity-agent"
      version = "v1.2.0-eksbuild.1"
    }
    {
      name    = "aws-guardduty-agent"
      version = "v1.4.1-eksbuild.2"
    }
    */
  ]

  /*
  fargate_profiles = {
    kube = {
      selectors = [
        {
          namespace = "kube-system"
          labels    = { k8s-app = "kube-dns" }
        },
        {
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name"     = "aws-load-balancer-controller",
            "app.kubernetes.io/instance" = "aws-load-balancer-controller"
          }
        },
        {
          namespace = "kube-system"
          labels    = {}
        }
      ]
    },
    apps = {
      selectors = [
        {
          namespace = "default"
          labels    = {}
        },
        {
          namespace = "apps"
          labels    = {}
        }
      ]
    }
  }
  */
}



