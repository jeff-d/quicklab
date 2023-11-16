#!/bin/bash

# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


# This script prints summary of QuickLab k8s-managed load balancers, 
# watching for any 'provisioning' load balancers to become 'active'.

profile=$(terraform output -raw aws_profile)
region=$(terraform output -raw aws_region)
vpc=$(terraform output -raw network_id)
lbs=$(
  aws elbv2 describe-load-balancers \
    --profile $profile \
    --region $region \
    --query "LoadBalancers[?VpcId=='$vpc'].LoadBalancerName" \
    --output text
)

if [ -z "$lbs" ]; then
  printf "%s\n" "  No Load Balancers found."
else 
  aws elbv2 describe-load-balancers \
    --profile $profile \
    --region $region \
    --query "LoadBalancers[?VpcId=='$vpc'].{Name:LoadBalancerName,Type:Type,Scheme:Scheme,State:State.Code,CreatedAt:CreatedTime,VPC:VpcId}" \
    --output table 
    
  for lb in $lbs; do
    state=$(
      aws elbv2 describe-load-balancers \
        --profile $profile \
        --region $region \
        --names=$lb --query "LoadBalancers[0].State.Code" \
        --output text
    )
  
    if [[ "$state" == "active" ]]; then
      continue
    fi

    printf "%s\n" "$lb State:"

    while [[ "$state" != "active" ]]
      do 
        printf "%s\n" "  $state"
        sleep 10
        state=$(
          aws elbv2 describe-load-balancers \
            --profile $profile \
            --region $region \
            --names=$lb  \
            --query "LoadBalancers[0].State.Code" \
            --output text
        )
        if [[ "$state" == "active" ]]; then
          printf "%s\n" "  $state"
          continue
        fi
      done
  done
fi