#!/bin/bash

# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


set -e
# set -u
set -o pipefail
# trap exit_trap EXIT

## CONSTANTS
scriptName="$(basename ${0})"
profile=$(terraform output -raw aws_profile)
region=$(terraform output -raw aws_region)
rg=$(terraform output -raw aws_resource_group)
prefix=${rg%%-*}
lab_id=$(terraform output -raw _lab_id)
project=$(terraform output -raw _project)
vpc_id=$(terraform output -raw network_id)
vpc_name=$(
    aws ec2 describe-vpcs \
      --profile $profile \
      --region $region \
      --vpc-ids $vpc_id \
      --query 'Vpcs[0].{Name:Tags[?Key==`Name`]|[0].Value}' \
      --output text
  )

app_name="${project:='public-app'}"


## FUNCTIONS

# USAGE
function usage(){
  banner
  printf "%s\n"  "Usage: $scriptName [-i | -u ]"
  printf "%s\n"
  printf "%s\n" "parameters:"
  printf "%s\n" "  -i [install]      install app infrastructure in QuickLab network"
  printf "%s\n" "  -u [uninstall]    uninstall the app infrastructure from QuickLab cluster that was installed by this script"
  printf "%s\n"
}

# OPTIONS
function get_opts() {
  local OPTIND
  while getopts ":iu" option; do
    case "$option" in
      i  ) task="install" ;; 
      u  ) task="uninstall" ;;
      \? ) printf "%s\n" "Unknown option: -$OPTARG" >&2; usage; exit 1;;
    esac
  done

  shift "$((OPTIND - 1))"

  if [ -z "$task" ]; then
    printf "%s\n" "Use either the -i or -u paramater."
    usage
    exit
  fi
}

# EXIT
exit_trap () {
  local lc="$BASH_COMMAND" rc=$?
  printf "%s\n" "Command [$lc] exited with code [$rc]"
}

# BANNER
function banner() {
cat << "EOF"

  _______       _____      ______ ______        ______
  __  __ \___  ____(_)________  /____  / ______ ___  /_
  _  / / /  / / /_  /_  ___/_  //_/_  /  _  __ `/_  __ \
  / /_/ // /_/ /_  / / /__ _  ,<  _  /___/ /_/ /_  /_/ /
  \___\_\\__,_/ /_/  \___/ /_/|_| /_____/\__,_/ /_.___/

                                            quicklab.io
  
EOF
  printf "%s\n" "$scriptName"
  printf "%s\n"
} 

# MANAGE SECURITY GROUPS
function create_security_groups() {

  timestamp=$(date +"%r")
  printf "%s\n" "  + Security Groups"
  # create sgfront
  sgfront=$(
    aws ec2 create-security-group \
      --region $region \
      --profile $profile \
      --vpc-id $vpc_id \
      --group-name $app_name-front \
      --description "allow internet traffic to reach $app_name ALB" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$app_name-front},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
      --query "GroupId" \
      --output text
  ) 
  printf "%s\n" "$app_name-front ($sgfront)" | awk '{ print "    " $0; }'

  sgback=$(
    aws ec2 create-security-group \
      --region $region \
      --profile $profile \
      --vpc-id $vpc_id \
      --group-name $app_name-back \
      --description "allow $app_name app traffic in to ALB target group instances" \
      --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$app_name-back},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
      --query "GroupId" \
      --output text
  )
  printf "%s\n" "$app_name-back ($sgback)" | awk '{ print "    " $0; }'

  # revoke default outbound rule from back
  aws ec2 revoke-security-group-egress \
    --region $region \
    --profile $profile \
    --group-id $sgback \
    --protocol all \
    --port all \
    --cidr 0.0.0.0/0 \
    > /dev/null

  # sample output:
  #  {
  #      "Return": true
  #  }

  # printf "%s\n" "  + security group rules"
  # authorize rules: sgfront
  # inbound (from internet)
  aws ec2 authorize-security-group-ingress \
    --region $region \
    --profile $profile \
    --group-id $sgfront \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "allow HTTP in from internet"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-FROM-INTERNET},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null 

  aws ec2 authorize-security-group-ingress \
    --region $region \
    --profile $profile \
    --group-id $sgfront \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "allow HTTPS in from internet"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-FROM-INTERNET},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null 

  # outbound (to app)
  aws ec2 authorize-security-group-egress \
    --region $region \
    --profile $profile \
    --group-id $sgfront \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "UserIdGroupPairs": [{"Description": "allow HTTP out to target group", "GroupId": "'${sgback}'", "VpcId": "'${vpc_id}'"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-TO-TARGETGROUP},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null

  aws ec2 authorize-security-group-egress \
    --region $region \
    --profile $profile \
    --group-id $sgfront \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "UserIdGroupPairs": [{"Description": "allow HTTPS out to target group", "GroupId": "'${sgback}'", "VpcId": "'${vpc_id}'"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-TO-TARGETGROUP},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null  

  # authorize rules: sgback
  # inbound (from ALB)
  aws ec2 authorize-security-group-ingress \
    --region $region \
    --profile $profile \
    --group-id $sgback \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "UserIdGroupPairs": [{"Description": "allow HTTP in from ALB", "GroupId": "'${sgfront}'", "VpcId": "'${vpc_id}'"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-FROM-ALB},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null 

  aws ec2 authorize-security-group-ingress \
    --region $region \
    --profile $profile \
    --group-id $sgback \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "UserIdGroupPairs": [{"Description": "allow HTTPS in from ALB", "GroupId": "'${sgfront}'", "VpcId": "'${vpc_id}'"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-FROM-ALB},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null
  
  # outbound (to ALB)
  aws ec2 authorize-security-group-egress \
    --region $region \
    --profile $profile \
    --group-id $sgback \
    --ip-permissions '[{"IpProtocol": "-1", "UserIdGroupPairs": [{"Description": "allow all out to ALB", "GroupId": "'${sgfront}'", "VpcId": "'${vpc_id}'"}]}]' \
    --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=ALL-TO-ALB},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    > /dev/null

}
function delete_security_groups() {

  # get security groups
  sg_ids=$(
    aws ec2 describe-security-groups \
      --region $region \
      --profile $profile \
      --filters Name=vpc-id,Values=$vpc_id Name=tag:CreatedWith,Values=$scriptName \
      --query 'SecurityGroups[*].GroupId' \
      --output text
  )

  if [ -z "$sg_ids" ]; then
    # handle case where there are no groups to clean up
    printf "%s\n" "  - Security Groups (none)"
  else 
    printf "%s\n" "  - Security Groups"

    # delete security group rules
    for id in $sg_ids; do
      printf "%s\n" "$id" | awk '{ print "    " $0; }'

      # delete group's egress rules
      egress_rules=$(
        aws ec2 describe-security-group-rules \
          --region $region \
          --profile $profile \
          --filters Name="group-id",Values="$id" \
          --query "SecurityGroupRules[?IsEgress != \`false\`].SecurityGroupRuleId" \
          --output text
      )

      # handle case where there are no egress rules to clean up
      if [ -z "$egress_rules" ]; then
        printf "%s\n" "Egress Rules (none)" | awk '{ print "     " $0; }'
      else 
        printf "%s\n" "Egress Rules" | awk '{ print "     " $0; }'
        aws ec2 revoke-security-group-egress \
            --region $region \
            --profile $profile \
            --group-id $id \
            --security-group-rule-ids $egress_rules \
            > /dev/null


      fi

      # delete group's ingress rules
      ingress_rules=$(
        aws ec2 describe-security-group-rules \
          --region $region \
          --profile $profile \
          --filters Name="group-id",Values="$id" \
          --query "SecurityGroupRules[?IsEgress == \`false\`].SecurityGroupRuleId" \
          --output text
      )

      # handle case where there are no ingress rules to clean up
      if [ -z "$ingress_rules" ]; then
        printf "%s\n" "Ingress Rules (none)" | awk '{ print "     " $0; }'
      else 
        printf "%s\n" "Ingress Rules" | awk '{ print "     " $0; }'
        aws ec2 revoke-security-group-ingress \
            --region $region \
            --profile $profile \
            --group-id $id \
            --security-group-rule-ids $ingress_rules \
            > /dev/null
      fi  
    done
    
    sleep 10 # creates delay between rule deletion and group deletion

    # delete security groups
    for id in $sg_ids; do
      # check for ENIs in security group
      delete_status=$(
        aws ec2 delete-security-group \
        --region $region \
        --profile $profile \
        --group-id $id \
        2>&1
      ) || :

      # printf "%s\n" "DEBUG security group delete_status = $delete_status" | awk '{ print "    " $0; }'

      while [[ "$delete_status" == *"DependencyViolation"* ]]
      # An error occurred (DependencyViolation) when calling the DeleteSecurityGroup operation: 
      # resource sg-02577125a47a1cea9 has a dependent object
        do
          sleep 5
          delete_status=$(
            aws ec2 delete-security-group \
            --region $region \
            --profile $profile \
            --group-id $id
          )

          if [ -z $delete_status ]; then
            printf "%s\n" "$id" | awk '{ print "    " $0; }'
          fi
        done
    done
  fi

}

# MANAGE APPLICATION LOAD BALANCER
function create_alb() {
  timestamp=$(date "+%Y%m%d-%H%M%S")
  printf "%s\n" "  + Application Load Balancer"
  public_subnet_a=$(
    aws ec2 describe-subnets \
      --profile $profile \
      --region $region \
      --filters Name=vpc-id,Values=$vpc_id "Name=tag:Name,Values=*public*" "Name=availability-zone,Values=${region}a" \
      --query 'Subnets[*].{SubnetId:SubnetId}' \
      --output text
  )
  public_subnet_b=$(
    aws ec2 describe-subnets \
      --profile $profile \
      --region $region \
      --filters Name=vpc-id,Values=$vpc_id "Name=tag:Name,Values=*public*" "Name=availability-zone,Values=${region}b" \
      --query 'Subnets[*].{SubnetId:SubnetId}' \
      --output text
  )
  alb_arn=$(
    aws elbv2 create-load-balancer \
      --region $region \
      --profile $profile \
      --name $app_name-alb \
      --type application \
      --scheme internet-facing \
      --subnets $public_subnet_a $public_subnet_b \
      --security-groups $sgfront \
      --tags Key=project,Value=$project Key=CreatedWith,Value=$scriptName Key=CreatedAt,Value=$timestamp \
      --query 'LoadBalancers[0].LoadBalancerArn' \
      --output text \
  )

  alb_dnsname=$(
    aws elbv2 describe-load-balancers \
      --profile $profile \
      --region $region \
      --load-balancer-arns $alb_arn \
      --query "LoadBalancers[0].DNSName" \
      --output text
  )
  printf "%s\n" "http://$alb_dnsname" | awk '{ print "    " $0; }'
  
  # create target group
  tg=$(
    aws elbv2 create-target-group \
      --region $region \
      --profile $profile \
      --name $app_name-targets \
      --vpc-id $vpc_id \
      --protocol HTTP \
      --port 80 \
      --ip-address-type ipv4 \
      --health-check-interval-seconds 5 \
      --health-check-timeout-seconds 2 \
      --healthy-threshold-count 2 \
      --unhealthy-threshold-count 2 \
      --tags Key=Project,Value=$project Key=CreatedWith,Value=$scriptName Key=CreatedAt,Value=$timestamp \
      --query 'TargetGroups[0].TargetGroupArn' \
      --output text
  )
  printf "%s\n" "  + Target Group"
  printf "%s\n" "$app_name-targets" | awk '{ print "    " $0; }'

  # lower deregistration delay
  aws elbv2 modify-target-group-attributes \
    --profile $profile \
    --region $region \
    --target-group-arn $tg \
    --attributes Key=deregistration_delay.timeout_seconds,Value=0 \
    > /dev/null  
  
  # describe target health
  aws elbv2 describe-target-health \
    --region $region \
    --profile $profile \
    --target-group-arn $tg \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
  
  # create listener
  listener=$(
    aws elbv2 create-listener \
    --region $region \
    --profile $profile \
    --load-balancer-arn $alb_arn \
    --protocol HTTP \
    --port 80  \
    --default-actions Type=forward,TargetGroupArn=$tg \
    --query 'Listeners[0].ListenerArn' \
    --output text
  )
  printf "%s\n" "  + Listener"
  printf "%s\n" "protocol: HTTP, port: 80" | awk '{ print "    " $0; }'


}
function delete_alb() {

  alb_arn=$(
    aws elbv2 describe-load-balancers \
      --profile $profile \
      --region $region \
      --names $app_name-alb \
      --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" \
      --output text \
    2>&1
  )  || : # continue despite nonzero exit code if no ALB found
  
  if [[ "$alb_arn" == *"Load balancers '[$app_name-alb]' not found" ]]; then
    # An error occurred (LoadBalancerNotFound) when calling the DescribeLoadBalancers 
    # operation: Load balancers '[project-hamster-alb]' not found
    # if [[ $? -eq 254 ]]; then
    printf "%s\n" "  - Application Load Balancer (none)"
    # printf "%s\n" "  DEBUG: alb_arn=$alb_arn"
  else
    
    # delete listener
    listener=$(
      aws elbv2 describe-listeners \
        --region $region \
        --profile $profile \
        --load-balancer-arn $alb_arn \
        --query 'Listeners[0].ListenerArn' \
        --output text
    )
    if [ -z "$listener" ]; then
      printf "%s\n" "  - Listener (none)"
    else
      printf "%s\n" "  - Listener"
      aws elbv2 delete-listener \
        --region $region \
        --profile $profile \
        --listener-arn $listener
    fi

    # deregister targets
    targets=( 
      $(
        aws ec2 describe-instances \
          --profile $profile \
          --region $region \
          --filters "Name=vpc-id,Values=$vpc" "Name=tag:LabId,Values=$lab_id" "Name=tag:Name,Values=*linux*" "Name=tag:CreatedWith,Values=$app_name-asg" "Name=tag:Project,Values=$project" \
          --query 'Reservations[*].Instances[*].{InstanceId:InstanceId}' \
          --output text \
          | awk -v ORS=" " '{print $1}'
      ) 
    )
    if [ -z "$targets" ]; then
      printf "%s\n" "  - Deregistering Targets (none)"
    else
      # printf "%s\n" "DEBUG: $targets"
      printf "%s\n" "  - deregistering targets"
      # solve for n number of targets
      aws elbv2 deregister-targets \
        --region $region \
        --profile $profile \
        --target-group-arn $tg \
        --targets Id=${targets[1]} Id=${targets[2]}
    fi

    # delete target group
    target_group=$(
      aws elbv2 describe-target-groups \
        --profile $profile \
        --region $region \
        --names $app_name-targets \
        --query "TargetGroups[0].TargetGroupArn" \
        --output text \
      2>&1
    )  || : # continue despite nonzero exit code if no target group found
    if [[ "$target_group" == *"One or more target groups not found" ]]; then
      # An error occurred (TargetGroupNotFound) when calling the DescribeTargetGroups 
      # operation: One or more target groups not found
      # exited with code [254]
      # printf "%s\n" "      DEBUG: One or more target groups not found" 
      printf "%s\n" "  - target group (none)"
    else
      printf "%s\n" "  - Target Group"
      aws elbv2 delete-target-group \
        --region $region \
        --profile $profile \
        --target-group-arn $target_group
    fi

    #delete ALB
    printf "%s\n" "  - Application Load Balancer"    
    aws elbv2 delete-load-balancer \
      --region $region \
      --profile $profile \
      --load-balancer-arn $alb_arn
  fi
}
  
# MANAGE INSTANCE ROLE & PROFILE
function create_instance_profile() {
  # timestamp=$(date "+%Y%m%d-%H%M%S")
  timestamp=$(date "+%Y%m%d-%H%M%S")
  # create IAM role
  # IAM role trust policy enables EC2 instances to assume the instance profile
  printf "%s\n" "  + Instance Role"
  aws iam create-role \
    --profile $profile \
    --role-name $app_name-instance-role \
    --description "enables EC2 instances to access SSM parameters and Secrets Manager secrets" \
    --tags Key=Project,Value=$project Key=CreatedWith,Value=$scriptName Key=CreatedAt,Value="$timestamp" \
    --query 'Role.RoleName' \
    --output text \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                  "Service": [
                      "ec2.amazonaws.com"
                  ]
              },
              "Action": [
                  "sts:AssumeRole"
              ]
          }
        ]
      }' | awk '{ print "    " $0; }'

  # create IAM role permissions poilicy
  # custom policies optional

  # aws iam attach-role-policy
  # enable EC2 instances to read SSM Parameter Store parameters and Secrets Manager secrets
  policyArns=(arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess arn:aws:iam::aws:policy/SecretsManagerReadWrite)
  for arn in $policyArns; do 
    aws iam attach-role-policy \
      --profile $profile \
      --role-name $app_name-instance-role \
      --policy-arn $arn \
      > /dev/null
  done

  # create instance profile
  printf "%s\n" "  + Instance Profile"
  aws iam create-instance-profile \
    --profile $profile \
    --instance-profile-name  $app_name-instance-profile \
    --tags Key=CreatedAt,Value=$timestamp Key=Project,Value=$project Key=CreatedWith,Value=$scriptName \
    > /dev/null
  
  # add IAM role to instance profile
  aws iam add-role-to-instance-profile \
    --profile $profile \
    --instance-profile-name  $app_name-instance-profile \
    --role-name $app_name-instance-role \
    > /dev/null

  # list instance profiles  # defaults to all instance profiles
  aws iam list-instance-profiles \
    --profile $profile \
    --path-prefix "/"  \
    --query "InstanceProfiles[?InstanceProfileName == \`$app_name-instance-profile\`].InstanceProfileName"  \
    --output text \
    | awk '{ print "    " $0; }'
}
function delete_instance_profile() {
  instance_profile=$(
    aws iam list-instance-profiles \
      --profile $profile \
      --path-prefix "/"  \
      --query "InstanceProfiles[?InstanceProfileName == \`$app_name-instance-profile\`].InstanceProfileName" \
      --output text 
  )

  app_iam_role=$(
    aws iam get-role \
      --profile $profile \
      --role-name $app_name-instance-role \
      --query 'Role.RoleName' \
      --output text \
    2>&1 
  ) || : # continue despite nonzero exit code if no instance role found

  if [[ "$app_iam_role" == *"The role with name $app_name-instance-role cannot be found"* ]]; then
    # An error occurred (NoSuchEntity) when calling the GetRole operation: 
    # The role with name project-hamster-asg-instance-role cannot be found.
    printf "%s\n" "  - Instance Role (none)"
  else 
    if [ -z $instance_profile ]; then 
      # handles empty case
      printf "%s\n" "  - Instance Profile (none)"
    else
      printf "%s\n" "  - Instance Profile"
      # An error occurred (DeleteConflict) when calling the DeleteInstanceProfile operation: 
      # Cannot delete entity, must remove roles from instance profile first.

      # remove role from instance profile
      aws iam remove-role-from-instance-profile \
      --profile $profile \
      --instance-profile-name $instance_profile \
      --role-name $app_name-instance-role

      # delete instance profile (may need to validate no longer in use by and EC2 Instance)
      aws iam delete-instance-profile \
        --profile $profile \
        --instance-profile-name $instance_profile
    fi

    # detatch policies from IAM role (list-role-policies for inline and list-attached-role-policies for managed)
    # An error occurred (DeleteConflict) when calling the DeleteRole operation: 
    # Cannot delete entity, must detach all policies first.
    # Command [aws iam delete-role --profile $profile --role-name $app_name-instance-role] exited with code [254]    
    managed_policies=(
      $(
        aws iam list-attached-role-policies \
          --profile $profile \
          --role-name $app_name-instance-role \
          --query "AttachedPolicies[*].PolicyArn" \
          --output text
      )
    )

    # delete any custom IAM policies (may not apply)
    for policy in $managed_policies; do
      aws iam detach-role-policy \
      --profile $profile \
      --role-name $app_name-instance-role \
      --policy-arn $policy
    done

    # delete IAM role
    printf "%s\n" "  - Instance Role"
    aws iam delete-role \
      --profile $profile \
      --role-name $app_iam_role
  fi
}

# MANAGE UESR DATA SCRIPT FROM FILE/TEMPLATE
function create_user_data() {

  timestamp=$(date +"%r")
  printf "%s\n" "  + user data script"
  
  pwd=$(pwd)

  cat > $app_name-app-user-data.sh <<EOF
#!/bin/bash
set -v -e
# tested with Amazon Linux 2023

# get admin privileges
sudo su

# disable ssm agent
systemctl stop amazon-ssm-agent
systemctl disable amazon-ssm-agent

# install packages
dnf update -y
dnf install -y jq
jq --version
dnf install -y httpd.x86_64

# populate default page
cat >> /var/www/html/index.html <<!
<title>Hello World</title>
<h1>Public App</h1> 
<p>This page content was generated by EC2 user data</p>
<pre>
{
    "hello": "world",
    "from": "quicklab.io"
}
</pre>
<br>
<hr>
<br> 
\$(hostname -f)
<br>
!

# enable and start service
sudo systemctl enable httpd.service 
sudo systemctl start httpd.service
sudo systemctl status httpd.service

# give ec2-user permissions to modify apache
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www

# add group write permissions and to set the group ID on future subdirectories
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# create output logs
output : { all : '| tee -a /var/log/cloud-init-output.log' }
EOF

  printf "%s\n" "$pwd/$app_name-app-user-data.sh" | awk '{ print "    " $0; }'

}
function delete_user_data() {
  if [[ -f "$app_name-app-user-data.sh" ]] || [[ -f "$app_name-app-user-data.bak" ]]; then
    rm -f $app_name-app-user-data.*
    printf "%s\n" "  - User Data script"
    printf "%s\n" "$app_name-app-user-data.sh" | awk '{ print "    " $0; }'
  else
    printf "%s\n" "  - User Data script (none)"
  fi

}

# MANAGE LAUNGH TEMPLATE
function create_launch_template() {
  keyname=$prefix-$lab_id

  sg_remote_acecss_ssh=$(
    aws ec2 describe-security-groups \
      --region $region \
      --profile $profile \
      --filters Name=vpc-id,Values=$vpc_id \
      --query "SecurityGroups[?GroupName == \`remote-access-ssh\`].GroupId" \
      --output text
  )

  instance_profile_arn=$(
    aws iam list-instance-profiles \
    --profile $profile \
    --path-prefix "/"  \
    --query "InstanceProfiles[?InstanceProfileName == \`$app_name-instance-profile\`].Arn"  \
    --output text \
  )

  # base64 encode user data for use in launch template
  user_data_b64=$(base64 -i $app_name-app-user-data.sh)

  pwd=$(pwd)

  printf "%s\n" "  + Launch Template"

  cat << "EOF" > "$pwd/$app_name-launch-template-data.json"
  {
    "IamInstanceProfile": {
        "Arn": "%profile%"
    },
    "NetworkInterfaces": [
        {
            "DeleteOnTermination": true,
            "DeviceIndex": 0,
            "Groups": [
                "%sgback%",
                "%ssh%"
            ]
        }
    ],
    "ImageId": "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64",
    "InstanceType": "t3.micro",
    "KeyName": "%key%",
    "UserData": "%userdata%",
    "TagSpecifications": [
        {
            "ResourceType": "instance",
            "Tags": [
                {
                    "Key": "Project",
                    "Value": "%project%"
                },
                {
                    "Key": "Name",
                    "Value": "%prefix%-%lab_id%-%app_name%-webserver"
                }
            ]
        }
    ],
    "MetadataOptions": {
        "HttpTokens": "required",
        "HttpPutResponseHopLimit": 2,
        "HttpEndpoint": "enabled",
        "InstanceMetadataTags": "enabled"
    },
    "PrivateDnsNameOptions": {
        "EnableResourceNameDnsARecord": false
    }
  }
EOF

  sed -i.bak \
    -e "s#%profile%#$instance_profile_arn#g" \
    -e "s#%sgback%#$sgback#g" \
    -e "s#%ssh%#$sg_remote_acecss_ssh#g" \
    -e "s#%key%#$keyname#g" \
    -e "s#%userdata%#$user_data_b64#g" \
    -e "s#%project%#$project#g" \
    -e "s#%prefix%#$prefix#g" \
    -e "s#%lab_id%#$lab_id#g" \
    -e "s#%app_name%#$app_name#g" \
    "$app_name-launch-template-data.json"

  printf "%s\n" "$pwd/$app_name-launch-template-data.json" | awk '{ print "    " $0; }'
  
  timestamp=$(date +"%r")
  launch_template_id=$(
    aws ec2 create-launch-template \
    --profile $profile \
    --region $region \
    --launch-template-name $app_name-al2023-apache \
    --version-description "$timestamp: installs & enables apache" \
    --tag-specifications "ResourceType=launch-template,Tags=[{Key=LabId,Value=$lab_id},{Key=Project,Value=$project},{Key=CreatedWith,Value=$scriptName}]" \
    --launch-template-data file://$app_name-launch-template-data.json \
    --query "LaunchTemplate.LaunchTemplateId" \
    --output text
  )

  printf "%s\n" "$app_name-al2023-apache ($launch_template_id)" | awk '{ print "    " $0; }' 

}
function delete_launch_template() {

  launch_template_id=$(
    aws ec2 describe-launch-templates \
      --profile $profile \
      --region $region \
      --launch-template-names $app_name-al2023-apache \
      --query "LaunchTemplates[0].LaunchTemplateId" \
      --output text \
    2>&1
  ) || :


  if [[ "$launch_template_id" == "None" ]]; then
    printf "%s\n" "  - Launch Template (none)"
  elif [[ "$launch_template_id" == *"does not exist"* ]]; then
    # An error occurred (InvalidLaunchTemplateName.NotFoundException) when calling the DescribeLaunchTemplates operation: 
    # At least one of the launch templates specified in the request does not exist.
    printf "%s\n" "  - Launch Template (none)"
  else 
    printf "%s\n" "  - Launch Template"

    aws ec2 delete-launch-template \
      --profile $profile \
      --region $region \
      --launch-template-id $launch_template_id \
    > /dev/null

    # local launch template data
    if [[ -f "$app_name-launch-template-data.json" || -f "$app_name-launch-template-data.bak" ]]; then
      rm -f $app_name-launch-template-data.*
      printf "%s\n" "  - Launch Template data"
      printf "%s\n" "$app_name-launch-template-data.json" | awk '{ print "    " $0; }'
    else
      printf "%s\n" "  - Launch Template data (none)"
    fi

  fi

  

}

# MANAGE AUTOSCALING GROUP
function create_asg() {

  timestamp=$(date +"%r")
  printf "%s\n" "  + Auto Scaling Group"
  private_subnet_a=$(
    aws ec2 describe-subnets \
      --profile $profile \
      --region $region \
      --filters Name=vpc-id,Values=$vpc_id "Name=tag:Name,Values=*private*" "Name=availability-zone,Values=${region}a" \
      --query 'Subnets[*].{SubnetId:SubnetId}' \
      --output text
  )
  private_subnet_b=$(
    aws ec2 describe-subnets \
      --profile $profile \
      --region $region \
      --filters Name=vpc-id,Values=$vpc_id "Name=tag:Name,Values=*private*" "Name=availability-zone,Values=${region}b" \
      --query 'Subnets[*].{SubnetId:SubnetId}' \
      --output text
  )
  
  aws autoscaling create-auto-scaling-group \
    --profile $profile \
    --region $region \
    --auto-scaling-group-name $app_name-asg \
    --launch-template LaunchTemplateName=$app_name-al2023-apache,Version='$Latest' \
    --desired-capacity 2 \
    --min-size 1 \
    --max-size 6 \
    --vpc-zone-identifier "$private_subnet_a, $private_subnet_b" \
    --health-check-type ELB \
    --target-group-arns $tg \
    --tags "ResourceId=$app_name-asg,ResourceType=auto-scaling-group,PropagateAtLaunch=true,Key=CreatedBy,Value=$app_name-asg"
  

  asg_name=$(
    aws autoscaling describe-auto-scaling-groups \
    --profile $profile \
    --region $region \
    --auto-scaling-group-names $app_name-asg \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text
  )
  printf "%s\n" "$asg_name" | awk '{ print "    " $0; }'

}
function delete_asg() {

  asg_name=$(
    aws autoscaling describe-auto-scaling-groups \
    --profile $profile \
    --region $region \
    --auto-scaling-group-names $app_name-asg \
    --query 'AutoScalingGroups[0].AutoScalingGroupName' \
    --output text
  )
  if [[ "$asg_name" == "None" ]]; then
    # handle case where it's already deleted
    printf "%s\n" "  - Auto Scaling Group (none)"
  else
    timestamp=$(date +"%r") 
    printf "%s\n" "  - Auto Scaling Group (about ~2m from $timestamp)"

    # scale down
    aws autoscaling update-auto-scaling-group \
      --profile $profile \
      --region $region \
      --auto-scaling-group-name $app_name-asg \
      --desired-capacity 0 \
      --min-size 0
    
    as_instances=$(
      aws autoscaling describe-auto-scaling-instances \
        --profile $profile \
        --region $region \
        --query "AutoScalingInstances[?AutoScalingGroupName == '$app_name-asg'].InstanceId" \
        --output text \
    )

    while [[ "$as_instances" != "" ]]
    do
        printf "%s\n" "...scaling instances down to zero" | awk '{ print "    " $0; }'
        sleep 10
        
        as_instances=$(
          aws autoscaling describe-auto-scaling-instances \
            --profile $profile \
            --region $region \
            --query "AutoScalingInstances[?AutoScalingGroupName == '$app_name-asg'].InstanceId" \
            --output text \
        )

        if [ -z "$as_instances" ]; then
          timestamp=$(date +"%r")
          printf "%s\n" "...done ($timestamp)" | awk '{ print "    " $0; }'
          continue
        fi
    done

    # delete group
    delete_status=$(
      aws autoscaling delete-auto-scaling-group \
      --profile $profile \
      --region $region \
      --auto-scaling-group-name $asg_name \
      2>&1
    ) || :

    # printf "%s\n" "DEBUG ASG delete_status = $delete_status" | awk '{ print "    " $0; }'

    while [[ "$delete_status" != "" ]]
      # An error occurred (ScalingActivityInProgress) when calling the DeleteAutoScalingGroup operation: 
      # You cannot delete an AutoScalingGroup while there are scaling activities in progress for that group.

      # An error occurred (ResourceInUse) when calling the DeleteAutoScalingGroup operation: 
      # You cannot delete an AutoScalingGroup while there are instances or pending Spot instance request(s) still in the group.
      do
        sleep 5
        delete_status=$(
          aws autoscaling delete-auto-scaling-group \
          --profile $profile \
          --region $region \
          --auto-scaling-group-name $asg_name
        ) || :

        if [ -z $delete_status ]; then
          printf "%s\n" "$asg_name" | awk '{ print "    " $0; }'
          continue
        fi
      done
  fi

}

# INSTALL
function install() {

  printf "%s\n" "Installing $app_name app components:"
  create_security_groups
  create_alb
  create_instance_profile
  create_user_data
  create_launch_template
  create_asg
  
}

# UNINSTALL
function uninstall() {

  printf "%s\n" "Uninstalling $app_name app components:"
  delete_asg
  delete_alb
  delete_security_groups
  delete_instance_profile
  delete_user_data
  delete_launch_template
  
  ##! possible need to clean up orphaned instances from asg
  
}

# PREFLIGHT_CHECK
function preflight_check() {

  # dependency list
  dependencies=(aws jq)
  
  # check for dependencies
  for dependency in $dependencies; do
    
    if ! command -v $dependency &> /dev/null
    then
        echo "$dependency not installed, exiting..."
        exit
    fi

  done


}

## SCRIPT BODY
get_opts "$@"
banner
preflight_check
printf "%s\n" "QuickLab network: $vpc_name ($vpc_id)"
printf "%s\n"
if [[ "$task" == "install" ]]; then
  install
elif [[ "$task" == "uninstall" ]]; then
  uninstall
fi