terraform {

  required_version = "~> 1.4"

  backend "local" {}

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    sumologic = {
      source  = "SumoLogic/sumologic"
      version = "~> 2.23"
    }
  }
}
