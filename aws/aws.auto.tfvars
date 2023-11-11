#  _______       _____      ______ ______        ______
#  __  __ \___  ____(_)________  /____  / ______ ___  /_
#  _  / / /  / / /_  /_  ___/_  //_/_  /  _  __ `/_  __ \
#  / /_/ // /_/ /_  / / /__ _  ,<  _  /___/ /_/ /_  /_/ /
#  \___\_\\__,_/ /_/  \___/ /_/|_| /_____/\__,_/ /_.___/
#
# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


#====================
# Components
#====================
create_network = false  # (bool)
create_bastion = false  # (bool)
create_cluster = false  # (bool)
monitoring     = "none" # (string) Valid values include "none" or "sumo".


#====================
# Resources
#====================
# prefix      = "quicklab"

# Tags
project     = "my-project"
environment = "dev"
createdfor  = "testing"
createdwith = "terraform cli"
# owner       = "user@company.com" 
# createdby   = "me" # defaults to AWS IAM username



#====================
# Remote Access
#====================
# remoteaccesscidrs = [ "1.2.3.4/32", "5.6.7.8/32" ] # limit to 5 entries, 0.0.0.0/0 is not allowed


#====================
# Monitoring
#====================
# aws_account_name = "my-aws-account" # displays in Sumo Logic
# notify = "user@company.com" # an email recipient for sumo-related nofitications for operational and collection issues


#====================
# Terraform providers
#====================
# AWS
# aws_profile = "my-cli-profile"
# aws_region  = "us-west-2"

# Sumo Logic
# sumo_accounttype = "Enterprise Suite" # ("Free", "Trial", "Essentials", "Enterprise Operations", "Enterprise Security", "Enterprise Suite")
# sumo_org = ""
# sumo_accessid  = ""
# sumo_accesskey = ""
# sumo_env = "" # (lowercase "us1", "us2", "de", et al)
