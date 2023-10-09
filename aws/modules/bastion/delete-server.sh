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
vpc_name=$(
    aws ec2 describe-vpcs \
      --vpc-ids $vpc_id \
      --query 'Vpcs[0].{Name:Tags[?Key==`Name`]|[0].Value}' \
      --output text
  )

## FUNCTIONS

# EXIT
exit_trap () {
  local lc="$BASH_COMMAND" rc=$?
  printf "%s\n" "Command [$lc] exited with code [$rc]"
}

# DELETE INSTANCE
function delete_instance(){
  instance_state=""
  instance_name=""

  # all non-terminated instances
  instance_ids=$(
    aws ec2 describe-instances \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:CreatedWith,Values=create-server.sh" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
      --query 'Reservations[*].Instances[*].{InstanceId:InstanceId}' \
      --output text
  )

  if [[ -z "$instance_ids" ]]; then
    
    printf "%s\n" "Instances: (none)"

  else

    aws ec2 describe-instances \
      --instance-ids $instance_ids \
      --query 'Reservations[*].Instances[*].{InstanceId:InstanceId, Name:Tags[?Key==`Name`]|[0].Value, State:State.Name}' \
      --output table
    
    printf "%s\n"
    printf "%s\n" "Instance:"

    aws ec2 terminate-instances \
      --instance-ids $instance_ids \
      > /dev/null
    
    for instance in $instance_ids; do

      instance_name=$(
        aws ec2 describe-instances \
          --instance-id $instance \
          --query 'Reservations[0].Instances[0].{Name:Tags[?Key==`Name`]|[0].Value}' \
          --output text
      )

      instance_state=$(
        aws ec2 describe-instances \
          --instance-id $instance \
          --query 'Reservations[0].Instances[0].{State:State.Name}' \
          --output text
      )

      printf "%s\n" "  $instance ($instance_state)"

      while [[ "$instance_state" != "terminated" ]]
      do 

        printf "%s\n" "    $instance_state"
        sleep 10

        instance_state=$(
        aws ec2 describe-instances \
          --instance-id $instance \
          --query 'Reservations[0].Instances[0].{State:State.Name}' \
          --output text
        )

        if [[ "$instance_state" == "terminated" ]]; then
          printf "%s\n" "    $instance_state"
          continue
        fi
      
      done
  
    done

  fi

  printf "%s\n"

}

# DELETE KEYPAIR
function delete_keypair(){

  keypairs=$(
    aws ec2 describe-key-pairs \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:CreatedWith,Values=create-server.sh" \
      --query 'KeyPairs[*].{KeyName:KeyName}' \
      --output text
  )

  if [[ -z "$keypairs" ]]; then

    printf "%s\n" "Key Pairs: (none)"

  else

    printf "%s\n" "Key Pairs:"
    keypairs=$(
    aws ec2 describe-key-pairs \
      --filters "Name=tag:LabId,Values=$lab_id" "Name=tag:CreatedWith,Values=create-server.sh" \
      --query 'KeyPairs[*].{KeyName:KeyName}' \
      --output text
  )

    for keypair in $keypairs; do

      printf "%s\n" "  $keypair"
      aws ec2 delete-key-pair \
        --key-name $keypair

      rm -f $keypair.pem 

    done

  fi 
  
  printf "%s\n"
  
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
banner
printf "%s\n" "QuickLab network: $vpc_name ($vpc_id)"
printf "%s\n"
delete_instance
# delete_keypair