# QuickLab Project Notes

## General

- This is a side-project for me, and there is no offered "product support". Feel free to open github issues if you encounter bugs.
- While the lab resource footprint is intentionally minimal, created resources will incur charges.
- The ASCII art for "QuickLab" was generated using a [Text to ASCII generator](http://patorjk.com/software/taag/#p=display&f=Speed&t=QuickLab) with the "Speed" font.

## Terraform

- QuickLab uses local terraform state, which is appropritate for a single-user project that creates short-lived infrastructure resources. If you would like to co-manage a QuickLab with your friends, consider using a terraform deployment pattern that implements proper remote state storage and locking (e.g. [AWS S3 with DyanmoDB](https://www.terraform.io/language/settings/backends/s3))
- To avoid spurious terraform state diffs, QuickLab generates it's unique LabId using terraform's random provider rather than the uuid string function for reasons explained in the [terraform docs](https://developer.hashicorp.com/terraform/language/functions/uuid).
- QuickLab intentionally avoids using the community-supported [terraform-aws-modules](https://registry.terraform.io/namespaces/terraform-aws-modules) to minimize external dependencies and use only the configuration options needed for QuickLab components. The terraform-aws-modules for vpc, ec2-instance, eks, security-group, (et al) tend to include a flag for every possible option to configure, which makes them great thorough examples but unnecessarily complicated to use here.
- QuickLab intentionally avoids using terraform to manage kubernetes resources inside the QuickLab cluster (e.g. using the [Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)) and recommends QuickLab users manage kubernetes resources themselves, outside of terraform (e.g. with kubectl, helm, or kustomize) while letting terraform manage the state of EKS resources. For a good discussion of the issues here, See Nat Bennett's blog post ["Why you shouldn't use Terraform to manage Kubernetes workloads"](https://www.simplermachines.com/why-you-shouldnt-use-terraform-to-manage-kubernetes-deployments/).
- list of [providers used](requirements.md#terraform-providers)
- see the [resource graph](#terraform-graph)

## Roadmap

Next Up:

- AWS (cluster): ALB access logs
- AWS (monitoring): Linux-Opentelemetry App
- AWS (cluster): additional EKS addons
- AWS (sumo): Cloud SIEM Enterprise support
- AWS (network): zeek

## Changelog

Recently Added or Updated:

- AWS (cluster): added shell script to ease un/install of AstronomyShop app in QuickLab cluster
- AWS (sumo): EKS Control Plane App installed when Cluster enabled
- AWS (cluster): enabled EKS Control Plane Logs
- AWS: add unique Lab ID to enable multiple QuickLab instances in the same AWS account

## Project Manifest

```
tree quicklab --dirsfirst -I 'terraform.*'
```

## Terraform Graph

![!QuicLab Terraform Graph](quicklab-tf-graph.png)
_QuickLab, with all resources created and telemetry collection enabled_

- graph by [GraphViz](https://graphviz.org/) (`brew install graphviz`)
- generate with terraform cli command like `terraform graph | dot -Tpng > quicklab-tf-graph.png` (reference: [terraform graph](https://developer.hashicorp.com/terraform/cli/commands/graph#generating-images))

## Documentation

- [README](../README.md)
- [Requirements](requirements.md)
- [Usage](usage.md)
- [Working with QuickLab Components](components.md)
- [Private Servers](servers.md)
- [Sumo Logic Astronomy Shop](astroshop.md)
- [QuickLab Monitoring](monitoring.md)
- [Project Notes](notes.md)
