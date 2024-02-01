# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


# VPC
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  # Must be enabled for EFS support
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Component = local.module
    Name      = "${var.prefix}-${var.uid}-vpc" # ${var.uid}-${var.prefix}
    CreatedBy = var.creator
  }
}

# Prefix Lists
resource "aws_ec2_managed_prefix_list" "vpc" {
  name           = "${aws_vpc.this.tags_all.Name}-pl-vpc-cidr"
  address_family = "IPv4"
  max_entries    = 2

  entry {
    cidr        = aws_vpc.this.cidr_block
    description = "This VPC's primary CIDR block."
  }

  tags = {
    Component   = local.module
    Description = "VPC CIDRs"
    CreatedBy   = var.creator
  }
}
resource "aws_ec2_managed_prefix_list" "remote_access" {
  name           = "${aws_vpc.this.tags_all.Name}-pl-remote-access"
  address_family = "IPv4"
  max_entries    = 5 # keeps VPC Security Group rule list below 60

  entry {
    cidr        = var.myip
    description = "My workstation's ISP-issued Public IP"
  }

  dynamic "entry" {
    for_each = var.remoteaccesscidrs == null ? ["${aws_eip.ngw.public_ip}/32"] : var.remoteaccesscidrs
    content {
      description = "A CIDR which is authorized to access ${var.prefix} Network resources"
      cidr        = entry.value
    }
  }

  tags = {
    Component   = local.module
    Description = "Authorized Remote Access CIDRs"
    CreatedBy   = var.creator
  }
}

# Gateways
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-igw"
    CreatedBy = var.creator
  }
}
resource "aws_eip" "ngw" {
  domain = "vpc"

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-eip-ngw"
    CreatedBy = var.creator
  }
}
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.ngw.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-ngw"
    CreatedBy = var.creator
  }
}

# Subnets
resource "aws_subnet" "public_a" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = cidrsubnet("${aws_vpc.this.cidr_block}", 8, 1)
  availability_zone                           = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch                     = true
  private_dns_hostname_type_on_launch         = "resource-name"
  enable_resource_name_dns_a_record_on_launch = true

  # function expansion, ref: https://developer.hashicorp.com/terraform/language/expressions/function-calls#expanding-function-arguments
  tags = merge(
    {
      Component = local.module
      Name      = "${aws_vpc.this.tags_all.Name}-public-${data.aws_availability_zones.available.names[0]}"
      CreatedBy = var.creator
    },
    [var.create_cluster ? { "kubernetes.io/role/elb" = "1" } : null]...
  )

}
resource "aws_subnet" "public_b" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = cidrsubnet("${aws_vpc.this.cidr_block}", 8, 2)
  availability_zone                           = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch                     = true
  private_dns_hostname_type_on_launch         = "resource-name"
  enable_resource_name_dns_a_record_on_launch = true

  # function expansion, ref: https://developer.hashicorp.com/terraform/language/expressions/function-calls#expanding-function-arguments
  tags = merge(
    {
      Component = local.module
      Name      = "${aws_vpc.this.tags_all.Name}-public-${data.aws_availability_zones.available.names[1]}"
      CreatedBy = var.creator
    },
    [var.create_cluster ? { "kubernetes.io/role/elb" = "1" } : null]...
  )

}
resource "aws_subnet" "private_a" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = cidrsubnet("${aws_vpc.this.cidr_block}", 8, 10)
  availability_zone                           = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch                     = false
  private_dns_hostname_type_on_launch         = "ip-name" # required for EKS
  enable_resource_name_dns_a_record_on_launch = true      #? conflict with private_dns_hostname_type_on_launch = "ip-name"

  # function expansion, ref: https://developer.hashicorp.com/terraform/language/expressions/function-calls#expanding-function-arguments
  tags = merge(
    {
      Component = local.module
      Name      = "${aws_vpc.this.tags_all.Name}-private-${data.aws_availability_zones.available.names[0]}"
      CreatedBy = var.creator
    },
    [var.create_cluster ? { "kubernetes.io/role/internal-elb" = "1" } : null]...
  )

}
resource "aws_subnet" "private_b" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = cidrsubnet("${aws_vpc.this.cidr_block}", 8, 11)
  availability_zone                           = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch                     = false
  private_dns_hostname_type_on_launch         = "ip-name" # required for EKS
  enable_resource_name_dns_a_record_on_launch = true      #? conflict with private_dns_hostname_type_on_launch = "ip-name"

  # function expansion, ref: https://developer.hashicorp.com/terraform/language/expressions/function-calls#expanding-function-arguments
  tags = merge(
    {
      Component = local.module
      Name      = "${aws_vpc.this.tags_all.Name}-private-${data.aws_availability_zones.available.names[1]}"
      CreatedBy = var.creator
    },
    [var.create_cluster ? { "kubernetes.io/role/internal-elb" = "1" } : null]...
  )
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-rtb-public"
    CreatedBy = var.creator
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-rtb-private"
    CreatedBy = var.creator
  }
}

# Routes
resource "aws_route" "default_public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
  depends_on             = [aws_route_table.public]
}
resource "aws_route" "default_private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id # implies cross-zone fraffic for private_b
  depends_on             = [aws_route_table.private]
}

# Route Table Associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security Groups
# Security Group: Network Monitoring
resource "aws_security_group" "network_monitoring" {
  name        = "network-monitoring"
  description = "enables members to analyze packets from VPC traffic mirroring"
  vpc_id      = aws_vpc.this.id
  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-sg-netmon"
    CreatedBy = var.creator
  }
}
resource "aws_security_group_rule" "allow_vpctm_in" {
  type              = "ingress"
  description       = "allow VPC Traffic Mirror Sessions in from any CIDR"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.network_monitoring.id
}

# Security Group: Remote Access SSH
resource "aws_security_group" "remoteaccess_ssh" {
  name        = "remote-access-ssh"
  description = "enable members to accept SSH connections"
  vpc_id      = aws_vpc.this.id
  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-sg-remote-ssh"
    CreatedBy = var.creator
  }
}
resource "aws_security_group_rule" "allow_ssh_in" {
  type              = "ingress"
  description       = "allow SSH in from whitelisted CIDRs"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  prefix_list_ids   = [aws_ec2_managed_prefix_list.remote_access.id, aws_ec2_managed_prefix_list.vpc.id]
  security_group_id = aws_security_group.remoteaccess_ssh.id
}

# Security Group: Remote Access RDP
resource "aws_security_group" "remoteaccess_rdp" {
  name        = "remote-access-rdp"
  description = "enable members to accept RDP (TCP) connections"
  vpc_id      = aws_vpc.this.id
  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-sg-remote-rdp"
    CreatedBy = var.creator
  }
}
resource "aws_security_group_rule" "allow_rdp_in_tcp" {
  type              = "ingress"
  description       = "allow RDP in (TCP) from whitelisted CIDRs"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp" # -1 overrides from_port and to_port values to 0 (ALL)
  prefix_list_ids   = [aws_ec2_managed_prefix_list.remote_access.id, aws_ec2_managed_prefix_list.vpc.id]
  security_group_id = aws_security_group.remoteaccess_rdp.id
}
resource "aws_security_group_rule" "allow_rdp_in_udp" {
  type              = "ingress"
  description       = "allow RDP in (UDP) from whitelisted CIDRs"
  from_port         = 3389
  to_port           = 3389
  protocol          = "udp" # -1 overrides from_port and to_port values to 0 (ALL)
  prefix_list_ids   = [aws_ec2_managed_prefix_list.remote_access.id, aws_ec2_managed_prefix_list.vpc.id]
  security_group_id = aws_security_group.remoteaccess_rdp.id
}

# Security Group: Public Webserver
resource "aws_security_group" "public_webserver" {
  name        = "public-webserver"
  description = "enable members to accept HTTP and HTTPS"
  vpc_id      = aws_vpc.this.id
  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-sg-public-webserver"
    CreatedBy = var.creator
  }
}
resource "aws_security_group_rule" "allow_http_in" {
  type              = "ingress"
  description       = "allow HTTP in from anywhere (ipv4)"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_webserver.id
}
resource "aws_security_group_rule" "allow_https_in" {
  type              = "ingress"
  description       = "allow HTTPS in from anywhere (ipv4)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_webserver.id
}

#TODO: update security group ingress rule to new-style terraform resource, once they support a list of prefix_list_ids
/*
resource "aws_vpc_security_group_ingress_rule" "allow_rdp_in_tcp" {
  # only supports a single prefix_list
  security_group_id = aws_security_group.remoteaccess_rdp.id
  description       = "allow RDP in (TCP) from whitelisted CIDRs"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  prefix_list_id    = aws_ec2_managed_prefix_list.remote_access.id
}
resource "aws_vpc_security_group_ingress_rule" "allow_rdp_in_udp" {
  # only supports a single prefix_list
  security_group_id = aws_security_group.remoteaccess_rdp.id
  description       = "allow RDP in (UDP) from whitelisted CIDRs"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "udp"
  prefix_list_id    = aws_ec2_managed_prefix_list.remote_access.id
}
*/

# Security Group Rule: Allow All Out
resource "aws_vpc_security_group_egress_rule" "allow_all_out" {
  for_each = {
    "remoteaccess_ssh"   = "${aws_security_group.remoteaccess_ssh.id}"
    "remoteaccess_rdp"   = "${aws_security_group.remoteaccess_rdp.id}"
    "network_monitoring" = "${aws_security_group.network_monitoring.id}"
    "public_webserver"   = "${aws_security_group.public_webserver.id}"
  }
  description = "Allow all traffic out (IPv4)" # recreates default AWS SG outbound rule that terraform implicitly deletes
  # from_port   = 0 # not used when ip_protocol is -1
  # to_port     = 0 # not used when ip_protocol is -1
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  # ipv6_cidr_blocks  = ["::/0"]
  security_group_id = each.value
}

# VPC Flow Logs
resource "aws_flow_log" "this" {
  iam_role_arn         = aws_iam_role.flowlogs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flowlogs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  # log_format = "" # specify custom field selection and order for the flow log record

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-flowlog"
    CreatedBy = var.creator
  }
}
resource "aws_cloudwatch_log_group" "flowlogs" {
  name_prefix       = "${var.prefix}/${var.uid}/${local.module}/flowlogs/"
  skip_destroy      = false # if true, only removes tf resource from tf state, leaving log group and logs
  retention_in_days = 7

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-lg-flowlogs"
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid    = "RoleTrustPolicy"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "flowlogs" {
  name               = "${aws_vpc.this.tags_all.Name}-flowlogs"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Component = local.module
    CreatedBy = var.creator
  }
}
data "aws_iam_policy_document" "cwlogs" {
  statement {
    sid    = "PublishFlowLogs"
    effect = "Allow"
    actions = [
      # "logs:CreateLogGroup", # intentionally omitted to prevent late-publish log group resurrection
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flowlogs.arn}:*"]
  }
}
resource "aws_iam_role_policy" "flowlogs" {
  name   = "${aws_vpc.this.tags_all.Name}-flowlogs-publish"
  role   = aws_iam_role.flowlogs.id
  policy = data.aws_iam_policy_document.cwlogs.json
}

# SSH Keys
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_sensitive_file" "kp" {
  content         = tls_private_key.this.private_key_pem
  filename        = pathexpand("~/.ssh/${var.prefix}-${var.uid}.pem")
  file_permission = "0600"
}
resource "aws_key_pair" "ssh" {
  key_name   = "${var.prefix}-${var.uid}"
  public_key = tls_private_key.this.public_key_openssh

  tags = {
    Component = local.module
    Name      = "${aws_vpc.this.tags_all.Name}-kp"
    CreatedBy = var.creator
  }
}
