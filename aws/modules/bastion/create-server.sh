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
rg=$(terraform output -raw _lab_resource_group)
prefix=${rg%%-*}
lab_id=$(terraform output -raw _lab_id)
vpc_id=$(terraform output -raw network_id)
vpc_name=$( aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].{Name:Tags[?Key==`Name`]|[0].Value}' --output text)


## FUNCTIONS

# EXIT
exit_trap () {
  local lc="$BASH_COMMAND" rc=$?
  printf "%s\n" "Command [$lc] exited with code [$rc]"
}

# USAGE
function usage(){
  banner
  printf "%s\n"  "Usage: $scriptName -s [-c]"
  printf "%s\n"
  printf "%s\n" "parameters:"
  printf "%s\n" "  -s system    system type (must be one of \"linux\" or \"windows\", default: \"linux\")"
  printf "%s\n" "  -c count     the number of Instances to create (default: 1)"
  printf "%s\n"
}

# CREATE RDP CONNECTION FILE
function localhost_rdp () {
  # creates a generic "localhost.rdp" file that can be used in conjunction with ssh -L 3389:$servername:3389

  if [ ! -f localhost.rdp ]
  then
    touch localhost.rdp
    printf "%s\n" "smart sizing:i:1" >> localhost.rdp
    printf "%s\n" "armpath:s:" >> localhost.rdp
    printf "%s\n" "enablerdsaadauth:i:0" >> localhost.rdp
    printf "%s\n" "targetisaadjoined:i:0" >> localhost.rdp >> localhost.rdp
    printf "%s\n" "hubdiscoverygeourl:s:" >> localhost.rdp >> localhost.rdp
    printf "%s\n" "redirected video capture encoding quality:i:0" >> localhost.rdp
    printf "%s\n" "camerastoredirect:s:" >> localhost.rdp
    printf "%s\n" "gatewaybrokeringtype:i:0" >> localhost.rdp
    printf "%s\n" "use redirection server name:i:0" >> localhost.rdp
    printf "%s\n" "alternate shell:s:" >> localhost.rdp
    printf "%s\n" "disable themes:i:0" >> localhost.rdp
    printf "%s\n" "geo:s:" >> localhost.rdp
    printf "%s\n" "disable cursor setting:i:1" >> localhost.rdp
    printf "%s\n" "remoteapplicationname:s:" >> localhost.rdp
    printf "%s\n" "resourceprovider:s:" >> localhost.rdp
    printf "%s\n" "disable menu anims:i:1" >> localhost.rdp
    printf "%s\n" "remoteapplicationcmdline:s:" >> localhost.rdp
    printf "%s\n" "promptcredentialonce:i:0" >> localhost.rdp
    printf "%s\n" "gatewaycertificatelogonauthority:s:" >> localhost.rdp
    printf "%s\n" "audiocapturemode:i:0" >> localhost.rdp
    printf "%s\n" "prompt for credentials on client:i:1" >> localhost.rdp
    printf "%s\n" "allowed security protocols:s:*" >> localhost.rdp
    printf "%s\n" "gatewayhostname:s:" >> localhost.rdp
    printf "%s\n" "remoteapplicationprogram:s:" >> localhost.rdp
    printf "%s\n" "gatewayusagemethod:i:2" >> localhost.rdp
    printf "%s\n" "screen mode id:i:2" >> localhost.rdp
    printf "%s\n" "use multimon:i:0" >> localhost.rdp
    printf "%s\n" "authentication level:i:2" >> localhost.rdp
    printf "%s\n" "desktopwidth:i:0" >> localhost.rdp
    printf "%s\n" "desktopheight:i:0" >> localhost.rdp
    printf "%s\n" "redirectsmartcards:i:1" >> localhost.rdp
    printf "%s\n" "redirectclipboard:i:1" >> localhost.rdp
    printf "%s\n" "forcehidpioptimizations:i:0" >> localhost.rdp
    printf "%s\n" "full address:s:localhost" >> localhost.rdp
    printf "%s\n" "drivestoredirect:s:" >> localhost.rdp
    printf "%s\n" "loadbalanceinfo:s:" >> localhost.rdp
    printf "%s\n" "networkautodetect:i:1" >> localhost.rdp
    printf "%s\n" "enablecredsspsupport:i:1" >> localhost.rdp
    printf "%s\n" "redirectprinters:i:1" >> localhost.rdp
    printf "%s\n" "autoreconnection enabled:i:1" >> localhost.rdp
    printf "%s\n" "session bpp:i:32" >> localhost.rdp
    printf "%s\n" "administrative session:i:0" >> localhost.rdp
    printf "%s\n" "audiomode:i:0" >> localhost.rdp
    printf "%s\n" "bandwidthautodetect:i:1" >> localhost.rdp
    printf "%s\n" "authoring tool:s:" >> localhost.rdp
    printf "%s\n" "connection type:i:7" >> localhost.rdp
    printf "%s\n" "remoteapplicationmode:i:0" >> localhost.rdp
    printf "%s\n" "disable full window drag:i:0" >> localhost.rdp
    printf "%s\n" "gatewayusername:s:" >> localhost.rdp
    printf "%s\n" "dynamic resolution:i:1" >> localhost.rdp
    printf "%s\n" "shell working directory:s:" >> localhost.rdp
    printf "%s\n" "wvd endpoint pool:s:" >> localhost.rdp
    printf "%s\n" "remoteapplicationappid:s:" >> localhost.rdp
    printf "%s\n" "username:s:" >> localhost.rdp
    printf "%s\n" "allow font smoothing:i:1" >> localhost.rdp
    printf "%s\n" "connect to console:i:0" >> localhost.rdp
    printf "%s\n" "disable wallpaper:i:0" >> localhost.rdp
    printf "%s\n" "gatewayaccesstoken:s:" >> localhost.rdp
  fi
 
}

# OPTIONS
function get_opts() {
  
  system="unspecified"

  local OPTIND
  while getopts ":c:s:" option; do
    case "$option" in
      c  ) count=$OPTARG;;
      s  ) system=$OPTARG;; # must be one of "linux", "windows"
      \? ) printf "%s\n" "Unknown option: -$OPTARG" >&2; usage; exit 1;;
      :  ) printf "%s\n" "Missing option argument for -$OPTARG" >&2; usage; exit 1;;
      *  ) printf "%s\n" "Unimplemented option: -$OPTARG" >&2; usage; exit 1;;
    esac
  done

  shift "$((OPTIND - 1))"

  # set defaults for unused options
  if [ -z "$count" ] ; then count=1 ; fi
 if [[ "$system" == "unspecified" ]]; then
    printf "%s\n" "Specify a system type."
    usage
    exit
  fi

  if [[ "$system" == "linux" ]]; then
    image_name=al2023-ami-kernel-default-x86_64
    image_id="resolve:ssm:/aws/service/ami-amazon-linux-latest/$image_name"
    type="t3.micro"
    sgid=$(
      aws ec2 describe-security-groups \
        --filters Name=vpc-id,Values=$vpc_id Name=group-name,Values=bastion-remote-access-ssh \
        --query "SecurityGroups[*].GroupId" \
        --output text
    )
    # image_name=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*-kernel-*-x86_64" --query 'reverse(sort_by(Images, &CreationDate))[0].Name' --output text)


  elif [[ "$system" == "windows" ]]; then
    localhost_rdp
    image_name=Windows_Server-2022-English-Full-Base
    image_id="resolve:ssm:/aws/service/ami-windows-latest/$image_name"
    type="t3.large"
    sgid=$(
      aws ec2 describe-security-groups \
        --filters Name=vpc-id,Values=$vpc_id Name=group-name,Values=bastion-remote-access-rdp \
        --query "SecurityGroups[*].GroupId" \
        --output text
    )
    # image_name=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=Windows_Server-2022-English-Full-Base*" --query 'reverse(sort_by(Images, &CreationDate))[0].Name' --output text)
  else
    usage
    exit 1
  fi
}

# SHUFFLE
function shuffle () {
  # avoids the need for GNU coreutils shuf
  declare -a array=("$@")
  r=$((RANDOM % ${#array[@]}))
  printf "%s\n" "${array[$r]}"
}

# CREATE INSTANCE
function create_instance(){
  
  priv_subnet_a=$(
    aws ec2 describe-subnets \
      --filters Name=vpc-id,Values=$vpc_id "Name=tag:Name,Values=*private*" "Name=availability-zone,Values=us-west-2a" \
      --query 'Subnets[*].{SubnetId:SubnetId}' \
      --output text
  )

  priv_subnet_b=$(
    aws ec2 describe-subnets \
      --filters Name=vpc-id,Values=$vpc_id "Name=tag:Name,Values=*private*" "Name=availability-zone,Values=us-west-2b" \
      --query 'Subnets[*].{SubnetId:SubnetId}' \
      --output text
  )

  printf "%s\n" "Creating $count new $type $system Instance(s) using $image_name"
  printf "%s\n"
  printf "%s\n" "Instances:"
  for (( i=1; i<=$count; i++ )); do
    rand=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6) || (ec=$? ; if [ "$ec" -eq 141 ]; then exit 0; else exit "$ec"; fi)
    timestamp=$(date "+%Y%m%d-%H%M%S")
    subnet_id=$(shuffle "$priv_subnet_a" "$priv_subnet_b")
  
    keyname=$(
      aws ec2 describe-key-pairs \
        --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:CreatedWith,Values=terraform cli" \
        --query 'KeyPairs[*].{KeyName:KeyName}' \
        --output text
    )

    instance_id=$(
      aws ec2 run-instances \
      --image-id $image_id \
      --instance-type $type \
      --key-name $keyname \
      --count 1 \
      --subnet-id $subnet_id \
      --security-group-ids $sgid \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$prefix-$lab_id-$system-$rand}, {Key=LabId,Value=$lab_id}, {Key=CreatedWith,Value=$scriptName}, {Key=CreatedAt,Value=$timestamp}]" \
      --query 'Instances[*].{InstanceId:InstanceId}' \
      --output text
    )

    instance_name=$(
      aws ec2 describe-instances \
        --instance-id $instance_id \
        --query 'Reservations[0].Instances[0].{Name:Tags[?Key==`Name`]|[0].Value}' \
        --output text
    )

    instance_priv_dns=$(
      aws ec2 describe-instances \
        --instance-id $instance_id \
        --query 'Reservations[0].Instances[0].{PrivateDnsName:PrivateDnsName}' \
        --output text
    )

    instance_state=$(
      aws ec2 describe-instances \
        --instance-id $instance_id \
        --query 'Reservations[0].Instances[0].{State:State.Name}' \
        --output text
    )

    printf "%s\n" "  $instance_id: $instance_state"

    while [[ "$instance_state" != "running" ]]
      do 

        printf "%s\n" "    $instance_state"
        sleep 10

        instance_state=$(
        aws ec2 describe-instances \
          --instance-id $instance_id \
          --query 'Reservations[0].Instances[0].{State:State.Name}' \
          --output text
        )

        if [[ "$instance_state" == "running" ]]; then
          printf "%s\n" "    $instance_state"
          continue
        fi
      
      done
  
  done
  

  printf "%s\n"

}

# CREATE KEYPAIR
function create_keypair(){

  instance_kp=$(
    aws ec2 create-key-pair \
      --key-name $prefix-$lab_id-$system-$rand \
      --query 'KeyMaterial' \
      --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$prefix-$lab_id-$system-$rand}, {Key=LabId,Value=$lab_id}, {Key=CreatedWith,Value=create-instance}]" \
      --output text \
      > $prefix-$lab_id-$system-$rand.pem
  )

  chmod 400 $prefix-$lab_id-$system-$rand.pem

}

# SUMMARY
function summary() {

  if [[ "$system" == "linux" ]]; then
    aws ec2 describe-instances \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:Name,Values=*linux*" "Name=tag:CreatedWith,Values=$scriptName" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
      --query 'Reservations[*].Instances[*].{InstanceId:InstanceId, Name:Tags[?Key==`Name`]|[0].Value, PrivateDnsName:PrivateDnsName, State:State.Name}' \
      --output table

    instance_id=$(
      aws ec2 describe-instances \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:Name,Values=*linux*" "Name=tag:CreatedWith,Values=$scriptName" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
      --query 'Reservations[0].Instances[0].{InstanceId:InstanceId}' \
      --output text
    )
    
    instance_priv_dns=$(
      aws ec2 describe-instances \
        --instance-id $instance_id \
        --query 'Reservations[0].Instances[0].{PrivateDnsName:PrivateDnsName}' \
        --output text
    )

    printf "%s\n"
    printf "%s\n" "To connect (linux):"
    printf "%s\n" "  1. note the PrivateDnsName of your server"
    printf "%s\n" "     example command: \"PrivateDnsName=$instance_priv_dns\" "
    printf "%s\n" "  2. connect to the server using the included ssh config file"
    printf "%s\n" "     example command: \"ssh -F $(terraform output -raw bastion_proxyjump_config) \$PrivateDnsName\" "

  elif [[ "$system" == "windows" ]]; then
    aws ec2 describe-instances \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:Name,Values=*windows*" "Name=tag:CreatedWith,Values=$scriptName" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
      --query 'Reservations[*].Instances[*].{InstanceId:InstanceId, Name:Tags[?Key==`Name`]|[0].Value, PrivateDnsName:PrivateDnsName, State:State.Name}' \
      --output table

    instance_id=$(
      aws ec2 describe-instances \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:Name,Values=*windows*" "Name=tag:CreatedWith,Values=$scriptName" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
      --query 'Reservations[0].Instances[0].{InstanceId:InstanceId}' \
      --output text
    )
    
    instance_priv_dns=$(
      aws ec2 describe-instances \
        --instance-id $instance_id \
        --query 'Reservations[0].Instances[0].{PrivateDnsName:PrivateDnsName}' \
        --output text
    )

    bastion_connect=$(terraform output -raw bastion_connect)

    printf "%s\n"
    printf "%s\n" "To connect (windows):"
    printf "%s\n" "  1. note server's Instance Id and PrivateDnsName"
    printf "%s\n" "     example command: \"InstanceId=$instance_id && PrivateDnsName=$instance_priv_dns\" "
    printf "%s\n" "  2. decrypt server's password"
    printf "%s\n" "     example command: \"aws ec2 get-password-data --instance-id \$InstanceId --priv-launch-key $(terraform output -raw network_keyfile) --query {AdminPassword:PasswordData} --output text\" "
    printf "%s\n" "  3. tunnel RDP traffic through an SSH connection to the QuickLab Bastion"
    printf "%s\n" "     example command: \"$bastion_connect -L 3389:\$PrivateDnsName:3389\" "
    printf "%s\n" "  4. use an RDP client to initiatiate an RDP connection to \"localhost\" using the generated RDP connection file"
    printf "%s\n" "     example command: \"open $PWD/localhost.rdp\""
    printf "%s\n" "  5. log in using the server's credentials, e.g username: \"Administrator\", password: <decrypted password>"
  fi

}

# BANNER
function banner() {
cat << "EOF"

  _______       _____      ______ ______        ______
  __  __ \___  ____(_)________  /____  / ______ ___  /_
  _  / / /  / / /_  /_  ___/_  //_/_  /  _  __ `/_  __ \
  / /_/ // /_/ /_  / / /__ _  ,<  _  /___/ /_/ /_  /_/ /
  \___\_\\__,_/ /_/  \___/ /_/|_| /_____/\__,_/ /_.___/

EOF

printf "%s\n" "$scriptName"
printf "%s\n"
}


## SCRIPT BODY
get_opts "$@"
banner
printf "%s\n" "QuickLab network: $vpc_name ($vpc_id)"
printf "%s\n"
create_instance
summary
printf "%s\n"