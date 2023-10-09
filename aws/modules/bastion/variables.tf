# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


variable "uid" {}
variable "prefix" {}
variable "project" {}
variable "creator" {}
variable "environment" {}
variable "vpc" {}
variable "bastion_az" {}
variable "bastion_subnet" {}
variable "ssh_key" {}
variable "ssh_key_filename" {}
variable "pl_vpc" {}
variable "pl_remoteaccess" {}
variable "sg_remoteaccess_ssh" {}
variable "sg_remoteaccess_rdp" {}
variable "monitoring" {}
