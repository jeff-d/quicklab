data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  module                = basename(abspath(path.module))
  cloud_init_merge_type = "list(append)+dict(no_replace,recurse_list)+str()" # "list(append)+dict()+str()"
}


# Latest AMI: AL2023 Standard
data "aws_ssm_parameter" "al23" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Latest AMI: AL2003 Minimal
data "aws_ssm_parameter" "al23min" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-minimal-kernel-default-x86_64"
}

# AWS-managed IAM Policies
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
data "aws_iam_policy" "CloudWatchAgentServerPolicy" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}
