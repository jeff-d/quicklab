data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "sumologic_personal_folder" "this" {
  for_each = var.monitoring == "sumo" ? toset(["sumo"]) : toset([])
}

locals {
  module       = basename(abspath(path.module))
  split_arn    = split("/", data.aws_caller_identity.current.arn)
  aws_username = element(local.split_arn, length(local.split_arn) - 1)
  aws_admins   = [local.aws_username, "administrator", "admin", "example1", "example2"]
  baseurl      = var.sumo_env == "us1" ? "https://api.sumologic.com" : "https://api.${var.sumo_env}.sumologic.com"
  basicauth    = "${var.sumo_accessid}:${var.sumo_accesskey}"
  app = {
    cloudtrail = {
      name        = "AWS CloudTrail"
      uuid        = "ceb7fac5-1137-4a04-a5b8-2e49190be3d4"
      description = "The Sumo Logic App for AWS CloudTrail helps you monitor your AWS deployments, with predefined dashboards that present user and administrator activity, network and security information, CloudTrail console logins, and information about your S3 buckets and public objects."
      fields      = []
    }
    costexplorer = {
      name        = "AWS Cost Explorer"
      uuid        = "14c40d09-f7d6-4162-a3f4-0f12b5fd04eb"
      description = "The Sumo Logic App for AWS Cost Explorer lets you visualize, understand, and manage your AWS costs and usage over time."
      fields      = ["account", "linkedaccount"]
    }
    flowlogs = {
      name        = "Amazon VPC Flow Logs"
      uuid        = "3546d789-3a45-48df-ac85-6838044d988d"
      description = "Amazon’s Virtual Private Cloud (VPC) Flow Logs contain the IP network traffic of your VPC, allowing you to troubleshoot traffic and security issues. The Sumo Logic App for Amazon VPC Flow Logs leverages this data to provide real-time visibility and analysis of your environment. It consists of predefined searches, and dashboards showing allowed and denied traffic."
      fields      = []
    }
    eks = {
      name        = "Amazon EKS - Control Plane"
      uuid        = "29d30e9e-8ee3-4c6f-973f-4001be84a55d"
      description = "Amazon Elastic Kubernetes Service (Amazon EKS) allows you to easily deploy, manage, and scale container-based applications with Kubernetes on AWS. The Sumo Logic App for Amazon EKS - Control Plane App provides visibility into the EKS control plane with operational insights into the api server, scheduler, control manager, and worker nodes. The app's preconfigured dashboards display resource-related metrics for Kubernetes deployments, clusters, namespaces, pods, containers, and daemonsets."
      fields      = []
    }
  }
  fields = {
    tags = ["labid", "prefix", "owner", "environment", "project", "createdby", "createdfor", "createdwith"]
    otc  = ["host.group", "deployment.environment"]
    resourcedetection = {
      system = ["host.name", "host.id", "os.type"]
      ec2    = ["cloud.provider", "cloud.platform", "cloud.account.id", "cloud.region", "cloud.availability_zone", "host.image.id", "host.type"]
    }
  }
}
