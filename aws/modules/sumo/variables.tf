# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


variable "aws_account_name" {}
variable "monitoring" {}
variable "uid" {}
variable "prefix" {}
variable "project" {}
variable "environment" {}
variable "creator" {}
variable "sumo_accessid" {}
variable "sumo_accesskey" {}
variable "sumo_env" {}
variable "sumo_org" {}
variable "notify" {}
variable "create_network" {}
variable "create_bastion" {}
variable "create_cluster" {}
variable "vpc" {}
variable "cwl_flowlogs" {}
variable "bastion_role" {}
