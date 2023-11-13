# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "sumologic_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"

  # Only Availability Zones (no Local Zones)
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
data "http" "workstation_external_ip" {
  url = "http://ipv4.icanhazip.com"
}

locals {
  module       = basename(abspath(path.module))
  uid          = lower(random_id.quicklab.id)
  split_arn    = split("/", data.aws_caller_identity.current.arn)
  aws_username = element(local.split_arn, length(local.split_arn) - 1)
  myip         = "${chomp(data.http.workstation_external_ip.response_body)}/32"
}
