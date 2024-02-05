#!/bin/bash

# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


# This script installs a the OpenTelemetry-Demo helm release into the QuickLab cluster, 
# and returns the app's public URL for usage.

set -e
set -u
set -o pipefail
# trap exit_trap EXIT

## CONSTANTS
scriptName="$(basename ${0})"
profile=$(terraform output -raw aws_profile)
region=$(terraform output -raw aws_region)
lab=$(terraform output -raw _lab_id)
release=astroshop
ns=apps
chart="modules/cluster/sumo-opentelemetry-demo/"

## FUNCTIONS
function exit_trap () {
  local lc="$BASH_COMMAND" rc=$?
  echo "Command $lc exited with code [$rc]"
}

function usage(){
  banner
  printf "%s\n"  "Usage: $scriptName [-i | -u ]"
  printf "%s\n"
  printf "%s\n" "parameters:"
  printf "%s\n" "  -i [install]      install astronomy shop application in QuickLab cluster"
  printf "%s\n" "  -u [uninstall]    uninstall the astronomy shop app from QuickLab cluster that was installed by this script"
  printf "%s\n"
}

function cluster_check() {

  # quicklab cluster check
  cluster=$(terraform output -raw cluster_name)
  if [[ $? -ne 0 ]]; then
    printf "%s\n" "ERROR [$?]: no QuickLab cluster found."
    exit 1
  fi
  
  # set kubernetes context
  set +u
  eval $(terraform output -raw cluster_kubeconfig)
  if [[ $? -ne 0 ]]; then
    printf "%s\n" "ERROR [$?]: unable to set QuickLab cluster kubeconfig."
    exit 1
  fi
  set -u

  # verify your kubernetes context
  kubeapi=$(kubectl cluster-info | grep "Kubernetes control plane")
  if [[ $? -ne 0 ]]; then
    printf "%s\n" "ERROR [$?]: to connect to QuickLab cluster."
    printf "%s\n" "To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'."
    exit 1
  fi

}

function get_opts() {
  
  task="unspecified"

  local OPTIND
  while getopts ":iu" option; do
    case "$option" in
      i  ) task="install" ;; 
      u  ) task="uninstall" ;;
      \? ) printf "%s\n" "Unknown option: -$OPTARG" >&2; usage; exit 1;;
    esac
  done

  shift "$((OPTIND - 1))"

  if [[ "$task" == "unspecified" ]]; then
    printf "%s\n" "Use either the -i or -u paramater."
    usage
    exit
  fi

}

function uninstall(){

  printf "%s\n"
  printf "%s\n" "Uninstalling AstronomyShop components:"

  # delete ingress
  istatus=$(kubectl -n $ns delete ingress/$release-frontend --ignore-not-found)
  if [[ "$istatus" == "ingress.networking.k8s.io \"$release-frontend\" deleted" ]]; then
    printf "%s\n" "  - kubernetes ingress and public load balancer"
    printf "%s\n" "    $istatus"
  else 
    printf "%s\n" "  - kubernetes ingress and public load balancer (none)"
  fi
  
  # uninstall helm release
  # test: [[ "$hstatus" == "Error: release: not found" ]] && printf "%s\n" " equal" || printf "%s\n" "not equal"
  hstatus=$(helm status $release -n $ns 2>&1) || : # continue despite nonzero exit code if no release found
  if [[ "$hstatus" == "Error: release: not found" ]]; then 
    printf "%s\n" "  - helm release (no $release release found in $ns)"
  else
    timestamp=$(date +"%r")
    printf "%s\n" "  - helm release (~5m from $timestamp)"
    helm uninstall $release -n $ns | awk '{ print "    " $0; }'
    sleep 30 # allow extra time for kubernetes to process pod removal
    timestamp=$(date +"%r")
    printf "%s\n" "    ($timestamp)"
  fi

  
  # identify orphaned resources in $ns
  # kubectl -n $ns get all
  # (expected output: pod/prometheus-astroshop-kube-prometheus-prometheus-0   1/2     Terminating   0          6h36m)


  # force-delete long grace-period pods
  podcount=$(kubectl -n $ns get pods --no-headers --ignore-not-found | wc -l | tr -d ' ')
  if [[ "$podcount" -eq 0 ]]; then 
    printf "%s\n" "  - remaining pods (none)"
  else 
    printf "%s\n" "  - $podcount remaining pod(s)" 
    kubectl -n $ns delete pods --all --grace-period=1 | awk '{ print "    " $0; }'
  fi
  

  # delete namespace
  nstatus=$(kubectl delete namespace $ns --ignore-not-found)
  if [[ "$nstatus" == "namespace \"$ns\" deleted" ]]; then
    printf "%s\n" "  - kubernetes namespace"
    printf "%s\n" "    $nstatus"
  else 
    printf "%s\n" "  - kubernetes namespace (none)" 
  fi


  # delete the prometheus service from the `kube-system` namespace
  # kubectl -n kube-system get svc
  pstatus=$(kubectl -n kube-system delete svc $release-kube-prometheus-kubelet --ignore-not-found=true 2>&1)
  if [[ "$pstatus" == "service \"$release-kube-prometheus-kubelet\" deleted"  ]]; then
    printf "%s\n" "  - remaining services"
    printf "%s\n" "    $pstatus"
  else 
    printf "%s\n" "  - remaining services (none)" 
  fi
}

function install() {

  printf "%s\n"
  printf "%s\n" "Installing AstronomyShop components:"

  # add open-telemetry helm repo
  # printf "%s\n" "  + helm repo"
  # helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts | awk '{ print "    " $0; }'
  # helm repo update | awk '{ print "    " $0; }'

  # create helm release
  timestamp=$(date +"%r")
  printf "%s\n" "  + helm release (~5m from $timestamp)"
  helm upgrade -i $release $chart --atomic --namespace $ns --create-namespace > /dev/null | awk '{ print "  " $0; }'
  timestamp=$(date +"%r")
  printf "%s\n" "    ($timestamp) release $release created successfully in namespace $ns from chart $chart"

  # watch application pods come up
  # kubectl -n $ns get pods --watch # timer?

  # expose app publicly
  now=$(date "+%M%S")
  timestamp=$(date +"%r")
  lbname="k8s-$lab-$release-frontend-$now"
  printf "%s\n" "  + kubernetes ingress and public load balancer (~2m from $timestamp)"
  kubectl -n $ns create ingress $release-frontend \
    --class='alb' \
    --rule="/*=$release-frontendproxy:8080" \
    --annotation alb.ingress.kubernetes.io/scheme=internet-facing \
    --annotation alb.ingress.kubernetes.io/target-type=ip \
    --annotation alb.ingress.kubernetes.io/load-balancer-name=$lbname \
  | awk '{ print "    " $0; }'

  # verify load balancer is `active`
  sleep 5
  source ./modules/cluster/lb.sh | awk '{ print "    " $0; }'
  timestamp=$(date +"%r")
  printf "%s\n" "    ($timestamp)"

  # installation summary
  dnsname=$(
    aws elbv2 describe-load-balancers \
      --profile $profile \
      --region $region \
      --names=$lbname \
      --query "LoadBalancers[0].DNSName" \
      --output text
  )
  app="http://$dnsname"

  printf "%s\n"
  printf "%s\n" "AstronomyShop basic usage:"
  printf "%s\n" "  * browse home page at $app"
  printf "%s\n" "  * inject app fault conditions at $app/feature/"
  printf "%s\n" "  * simulate application load at $app/loadgen/"

}


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
  printf "%s\n" "\"AstronomyShop\" is the OpenTelemetry Demo Application"
  printf "%s\n" "https://opentelemetry.io/docs/demo/"
  printf "%s\n"
} 



## SCRIPT BODY
get_opts "$@"
banner
cluster_check
printf "%s\n" "QuickLab cluster: $cluster"
printf "%s\n" "  $kubeapi"
if [[ "$task" == "install" ]]; then
  install
elif [[ "$task" == "uninstall" ]]; then
  uninstall
fi