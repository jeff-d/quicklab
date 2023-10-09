#!/bin/bash

# lb.sh
# This script prints summary of QuickLab k8s-managed load balancers, 
# watching for any 'provisioning' load balancers to become 'active'.

vpc=$(terraform output -raw network_id)
lbs=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$vpc'].LoadBalancerName" --output text)

if [ -z "$lbs" ]; then
  printf "%s\n" "  No Load Balancers found."
else 
  aws elbv2 describe-load-balancers --output table --query "LoadBalancers[?VpcId=='$vpc'].{Name:LoadBalancerName,Type:Type,Scheme:Scheme,State:State.Code,CreatedAt:CreatedTime,VPC:VpcId}"
  for lb in $lbs; do
    state=$(aws elbv2 describe-load-balancers --names=$lb --query "LoadBalancers[0].State.Code" --output text)
  
    if [[ "$state" == "active" ]]; then
      continue
    fi

    printf "%s\n" "$lb State:"

    while [[ "$state" != "active" ]]
      do 
        printf "%s\n" "  $state"
        sleep 10
        state=$(aws elbv2 describe-load-balancers --names=$lb  --query "LoadBalancers[0].State.Code" --output text)
        if [[ "$state" == "active" ]]; then
          printf "%s\n" "  $state"
          continue
        fi
      done
  done
fi