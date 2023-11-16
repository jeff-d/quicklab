# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later

provider "local" {}
provider "null" {}
provider "random" {}
provider "http" {}
provider "tls" {}
provider "time" {}
provider "aws" {
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = {
      LabId       = local.uid
      Owner       = var.owner
      Environment = var.environment
      Project     = var.project
      CreatedFor  = var.createdfor
      CreatedWith = var.createdwith
      # CreatedBy   = local.aws_username # this tag must be created on each individual resource to https://github.com/hashicorp/terraform-provider-aws/issues/28772
      # CreatedAt   = timestamp() # can't use timestamp() directly due to https://github.com/hashicorp/terraform-provider-aws/issues/19583
    }
  }
}
provider "sumologic" {
  access_id   = var.sumo_accessid
  access_key  = var.sumo_accesskey
  environment = var.sumo_env
}


resource "random_id" "quicklab" {
  byte_length = 3
}
resource "aws_resourcegroups_group" "this" {
  name        = "${var.prefix}-${local.uid}-resources"
  description = "terraform-managed resources for QuickLab lab id ${local.uid}."

  resource_query {
    query = <<-JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "LabId",
          "Values": ["${local.uid}"]
        }
      ]
    }
    JSON
  }
  tags = {
    Component = local.module
    Name      = "${var.prefix}-${local.uid}-resources"
    CreatedBy = local.aws_username
  }
}


module "network" {

  depends_on = [random_id.quicklab]

  for_each = var.create_network ? toset(["${local.uid}"]) : toset([])
  source   = "./modules/network"

  uid               = local.uid
  prefix            = var.prefix
  creator           = local.aws_username
  myip              = local.myip
  remoteaccesscidrs = var.remoteaccesscidrs
  create_cluster    = var.create_cluster # enable cluster subnet autodiscovery
}
module "bastion" {

  depends_on = [random_id.quicklab, module.network]

  for_each = var.create_network && var.create_bastion ? toset(["${local.uid}"]) : toset([])
  source   = "./modules/bastion"

  uid                 = local.uid
  prefix              = var.prefix
  project             = var.project
  creator             = local.aws_username
  environment         = var.environment
  vpc                 = module.network["${local.uid}"].vpc
  bastion_subnet      = module.network["${local.uid}"].public_subnet_a
  bastion_az          = module.network["${local.uid}"].subnet_public_a_az
  ssh_key             = module.network["${local.uid}"].ssh_key
  ssh_key_filename    = module.network["${local.uid}"].key_filename
  pl_vpc              = module.network["${local.uid}"].pl_vpc
  pl_remoteaccess     = module.network["${local.uid}"].pl_remoteaccess
  sg_remoteaccess_ssh = module.network["${local.uid}"].sg_remoteaccess_ssh_id
  sg_remoteaccess_rdp = module.network["${local.uid}"].sg_remoteaccess_rdp_id
  monitoring          = var.monitoring
}
module "cluster" {

  depends_on = [random_id.quicklab, module.network]

  for_each = var.create_network && var.create_cluster ? toset(["${local.uid}"]) : toset([])
  source   = "./modules/cluster"

  uid                         = local.uid
  aws_profile                 = var.aws_profile
  prefix                      = var.prefix
  creator                     = local.aws_username
  project                     = var.project
  environment                 = var.environment
  vpc                         = module.network["${local.uid}"].vpc
  ssh_key                     = module.network["${local.uid}"].ssh_key
  private_subnet_a            = module.network["${local.uid}"].private_subnet_a
  private_subnet_b            = module.network["${local.uid}"].private_subnet_b
  pl_remoteaccess             = module.network["${local.uid}"].pl_remoteaccess
  network_sg_remote_ssh       = length(module.network) > 0 ? module.network["${local.uid}"].sg_remote_ssh : null
  sumo_accessid               = var.sumo_accessid
  sumo_accesskey              = var.sumo_accesskey
  sumo_cluster_rum_traces_url = length(module.sumo) > 0 ? module.sumo["${local.uid}"].rum_traces_url : "n/a"
}
module "sumo" {

  depends_on = [random_id.quicklab]

  for_each = var.monitoring == "sumo" ? toset(["${local.uid}"]) : toset([])
  source   = "./modules/sumo"

  aws_account_name                  = var.aws_account_name
  monitoring                        = var.monitoring
  uid                               = local.uid
  prefix                            = var.prefix
  project                           = var.project
  environment                       = var.environment
  notify                            = var.notify
  sumo_accounttype                  = var.sumo_accounttype
  sumo_accessid                     = var.sumo_accessid
  sumo_accesskey                    = var.sumo_accesskey
  sumo_env                          = var.sumo_env
  sumo_org                          = var.sumo_org
  creator                           = local.aws_username
  create_network                    = var.create_network
  create_bastion                    = var.create_bastion
  create_cluster                    = var.create_cluster
  vpc                               = length(module.network) > 0 ? module.network["${local.uid}"].vpc : null
  cwl_flowlogs                      = length(module.network) > 0 ? module.network["${local.uid}"].cwlog_group_flowlogs : null
  bastion_role                      = length(module.bastion) > 0 ? module.bastion["${local.uid}"].bastion_role : null
  create_tag_fields                 = var.create_tag_fields
  create_app_fields                 = var.create_app_fields
  create_bastion_otelcol_fields     = var.create_bastion_otelcol_fields
  create_bastion_otelsystem_fields  = var.create_bastion_otelsystem_fields
  create_bastion_otelec2_fields     = var.create_bastion_otelec2_fields
  create_app_field_extraction_rules = var.create_app_field_extraction_rules
}
