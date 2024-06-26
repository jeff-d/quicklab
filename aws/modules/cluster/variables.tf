# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

variable "aws_profile" {}
variable "uid" {}
variable "prefix" {}
variable "creator" {}
variable "project" {}
variable "environment" {}
variable "vpc" {}
variable "ssh_key" {}
variable "private_subnet_a" {}
variable "private_subnet_b" {}
variable "pl_remoteaccess" {}
variable "bastion_sg" {}
variable "sumo_accessid" {}
variable "sumo_accesskey" {}
variable "sumo_cluster_rum_traces_url" {
}
variable "fullnameoverride" {
  default = ""
}
