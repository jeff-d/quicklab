# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


#====================
# Components
#====================
variable "create_network" {
  type        = bool
  description = "Feature flag for resource creation. Set to \"true\" to enable."
  default     = null
}
variable "create_bastion" {
  type        = bool
  description = "Feature flag for resource creation. Set to \"true\" to enable."
  default     = null
}
variable "create_cluster" {
  type        = bool
  description = "Feature flag for resource creation. Set to \"true\" to enable."
  default     = null
}
variable "monitoring" {
  type        = string
  description = "Feature flag for initializing Sumo Logic collection for QuickLab resources. Set to \"true\" to enable."
  default     = "none"

  validation {
    condition     = contains(["none", "sumo"], var.monitoring)
    error_message = "Valid values include \"none\" or \"sumo\"."
  }
}


#====================
# Resources
#====================
variable "prefix" {
  type        = string
  description = "Resource naming prefix"
  default     = "quicklab"
}

# Tags
variable "owner" {
  type        = string
  description = "a valid email address designating the resource's owner"
  default     = "-"
}
variable "environment" {
  type        = string
  description = "Environment designation (e.g. dev, prod)."
  default     = "-"
}
variable "project" {
  type        = string
  description = "Project name."
  default     = "-"
}
variable "createdby" {
  type        = string
  description = "userid or API key of resource's creator"
  default     = "-"
}
variable "createdfor" {
  type        = string
  description = "the resource creator's intention for this resource"
  default     = "-"
}
variable "createdwith" {
  type        = string
  description = "mechanism by which this a resource was created"
  default     = "-"
}


#====================
# Remote Access
#====================
variable "remoteaccesscidrs" {
  type        = list(string)
  description = "An IPv4 CIDR, expressed in slash notation, that is allowed to access systems inside the created Quicklab Network. Example: 1.2.3.4/20"
  default     = []


  validation {
    condition = alltrue([
      for i in var.remoteaccesscidrs : coalesce(can(cidrhost(i, 0)))
    ])
    error_message = "All list items must be valid IPv4 CIDRs"
  }
}


#====================
# Monitoring
#====================
variable "aws_account_name" {
  type        = string
  description = "A friendly name for the AWS Account to use with Sumo Logic Collection."
  default     = "my-aws-account"
}
variable "notify" {
  type        = string
  description = "an email recipient for sumo-related nofitications for operational and collection issues"
  default     = null
}


#====================
# Terraform providers
#====================
# AWS
variable "aws_profile" {
  type        = string
  description = "AWS CLI Profile."
  default     = null # defers to 'default' AWS CLI profile value
}
variable "aws_region" {
  type        = string
  description = "AWS Region."
  default     = null # defers to 'default' AWS CLI profile value
}

# Sumo Logic
variable "sumo_accounttype" {
  type        = string
  description = "Sumo Logic Cloud Flex Credits Account Type"
  default     = "Free"

  validation {
    condition     = contains(["Free", "Trial", "Essentials", "Enterprise Operations", "Enterprise Security", "Enterprise Suite"], var.sumo_accounttype)
    error_message = "Must be a valid Sumo Logic Cloud Flex Credits Account type. List at https://help.sumologic.com/docs/manage/manage-subscription/cloud-flex-credits-accounts/ ."
  }

}
variable "sumo_accessid" {
  type        = string
  description = "Sumo Logic Access ID"
  default     = "unspecified"
}
variable "sumo_accesskey" {
  type        = string
  description = "Sumo Logic Access Key"
  default     = "unspecified"
}
variable "sumo_env" {
  type        = string
  description = "Sumo Logic Deployment (e.g. us1)"
  default     = "us1"

  validation {
    condition     = var.sumo_env == null || can(contains(["au", "ca", "de", "eu", "fed", "in", "jp", "us1", "us2"], var.sumo_env))
    error_message = "Must be a valid Sumo Logic Deployment (case-sensitive). List at https://help.sumologic.com/docs/api/getting-started/#sumo-logic-endpoints-by-deployment-and-firewall-security ."
  }

}
variable "sumo_org" {
  type        = string
  description = "Sumo Logic Organization ID"
  default     = "unspecified"
}
