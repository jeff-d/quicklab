#====================
# QuickLab Components
#====================
create_network = false  # (bool)
create_bastion = false  # (bool)
create_cluster = false  # (bool)
monitoring     = "none" # (string) Valid values include "none" or "sumo".


#====================
# QuickLab Resources
#====================
# prefix      = "quicklab"

# Tags
# owner       = "user@company.com"
environment = "dev"
project     = "my-project"
createdwith = "terraform cli"
# createdby   = "me"
# createdfor  = "testing"


#====================
# QuickLab Remote Access
#====================
# remoteaccesscidrs = [ "1.2.3.4/32", "5.6.7.8/32" ] # (limit to 5 entries, 0.0.0.0/0 is not allowed)


#====================
# QuickLab Monitoring
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
# sumo_org = ""
# sumo_accessid  = ""
# sumo_accesskey = ""
# sumo_env = "" # (lowercase "us1", "us2", "de", et al)

