[comment]: # "This file is part of QuickLab, which creates simple, monitored labs."
[comment]: # "https://github.com/jeff-d/quicklab"
[comment]: #
[comment]: # "SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>"
[comment]: # "SPDX-License-Identifier: AGPL-3.0-or-later"

# About QuickLab

QuickLab's design philiosophy aims to balance two competing goals:

- minimalism, which promotes maintainability and cost-optimization
- a "batteries-included" experience, which doesn't require the QuickLab user to understand the internals of its underlying technologies (e.g. terraform, AWS, Kubernetes, and Sumo Logic).

## License

QuickLab creates simple, monitored labs.
Copyright (C) 2023 Jeffrey M. Deininger

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

## Project Notes

- While the lab resource footprint is intentionally minimal, created resources will incur charges.

- The ASCII art for "QuickLab" was generated using a [Text to ASCII generator](http://patorjk.com/software/taag/#p=display&f=Speed&t=QuickLab) with the "Speed" font.

- This terraform project incorporates much of the guidance and design principles found in [The AWS Integration & Automation Team's Best Practices for Terraform](https://aws-ia.github.io/standards-terraform/)

- QuickLab uses local terraform state, which is appropritate for a single-user project that creates short-lived infrastructure resources. If you would like to co-manage a QuickLab with your friends, consider using a terraform deployment pattern that implements proper remote state storage and locking (e.g. [AWS S3 with DyanmoDB](https://www.terraform.io/language/settings/backends/s3))

- To avoid spurious terraform state diffs, QuickLab generates it's unique LabId using terraform's random provider rather than the uuid string function for reasons explained in the [terraform docs](https://developer.hashicorp.com/terraform/language/functions/uuid).

- QuickLab intentionally avoids using the community-supported [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules) to minimize external dependencies and use only the configuration options needed for QuickLab components. The terraform-aws-modules for vpc, ec2-instance, eks, security-group, (et al) tend to include a flag for every possible option to configure, which makes them great thorough examples but unnecessarily complicated to use here.

- QuickLab intentionally avoids using terraform to manage kubernetes resources and recommends QuickLab users manage kubernetes resources themselves, outside of terraform (e.g. with kubectl, helm, or kustomize) while letting terraform manage the state of EKS resources. For a good discussion of the issues here, See Nat Bennett's blog post ["Why you shouldn't use Terraform to manage Kubernetes workloads"](https://www.simplermachines.com/why-you-shouldnt-use-terraform-to-manage-kubernetes-deployments/).

- Quicklab intentionally avoids using terraform to manage helm releases, for the resaons listed above, with the notable exception of installing the AWS Load Balancer Controller EKS addon using a terraform `null_resource` to call `helm upgrade -i`.

## Roadmap

Next Up:

- AWS (cluster): ALB access logs
- AWS (monitoring): Linux-Opentelemetry App
- AWS (cluster): additional EKS addons
- AWS (sumo): Cloud SIEM Enterprise support
- AWS (network): zeek

## Changelog

Recently Added or Updated:

- AWS (bastion): added shell scripts to create and delete servers in QuickLab network's private subnets
- AWS (cluster): added shell script to ease un/install of AstronomyShop app in QuickLab cluster
- AWS (sumo): EKS Control Plane App installed when Cluster enabled
- AWS (cluster): enabled EKS Control Plane Logs
- AWS: add unique Lab ID to enable multiple QuickLab instances in the same AWS account

## Documentation

- [Requirements](requirements.md)
- [Usage](usage.md)
- [Components](components.md)
- [About](about.md)
