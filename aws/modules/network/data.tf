data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"

  # Only Availability Zones (no Local Zones)
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
locals {
  module = basename(abspath(path.module))
}
