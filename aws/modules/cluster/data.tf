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
      version = "v1.18.0-eksbuild.1"
    }
    /*
    ,
    {
      name    = "kube-proxy"
      version = "v1.26.4-eksbuild.1"
    }
    {
      name    = "coredns"
      version = "v1.9.3-eksbuild.3"
    },
    {
      name    = "vpc-cni"
      version = "v1.12.6-eksbuild.1"
    },
    {
      name    = "aws-guardduty-agent"
      version = "v1.1.0-eksbuild.1"
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



