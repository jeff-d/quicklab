[comment]: # "This file is part of QuickLab, which creates simple, monitored labs."
[comment]: # "https://github.com/jeff-d/quicklab"
[comment]: #
[comment]: # "SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>"
[comment]: # "SPDX-License-Identifier: AGPL-3.0-or-later"

# Changelog

All notable changes to QuickLab are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [QuickLab's versioning policy](docs/versioning.md).

Each entry notes its **apply impact**: `no-op`, `in-place`, `replacement`, or `state migration`.

## [Unreleased]

## [1.0.0] - 2026-10-17

First tagged release. Captures the project's first 25 commits (2023-10-08 → 2024-09-05).

### Added

- **Network** — VPC, two-AZ public/private subnets, VPC Flow Logs to CloudWatch, generated SSH
  keypair, security groups scoped to the caller's public IP.
- **Bastion** — Amazon Linux 2023 EC2 instance bootstrapped via cloud-init with an OpenTelemetry
  Collector, plus a generated SSH ProxyJump config reaching private subnets and EKS nodes.
- **Cluster** — EKS with the Amazon EBS CSI Driver addon, AWS Load Balancer Controller, control
  plane logging, and a managed kubeconfig.
- **Monitoring** — `monitoring = "sumo"` provisions Sumo Logic collection and App Catalog content
  for CloudTrail, Cost Explorer, VPC Flow Logs, and the EKS control plane, with supporting fields
  and field extraction rules.
- Per-lab `LabId` tagged onto every resource, enabling concurrent labs in one AWS account, plus an
  AWS Resource Group for single-pane inventory.
- Companion scripts: `create-server.sh`, `delete-server.sh`, `app.sh`, `astroshop.sh`, `lb.sh`.
- The Astronomy Shop / OpenTelemetry Demo walkthrough and its vendored Helm chart.
- Documentation set and REUSE-compliant AGPL-3.0-or-later licensing.

### Changed

- `in-place` — Terraform falls back to the default AWS CLI profile when `aws_profile` is unset.
- `replacement` — Lab Id character set narrowed for AWS resource-naming compatibility.
- `in-place` — EKS addons use their default version where no pin is required.

### Fixed

- Sumo Logic S3 bucket name reference (#9).
- `TASK_QUEUE_URL` for `SumoCWProcessDLQLambdas`.
- `aws_profile` output; `astroshop.sh` and its generated values file reference.
- IMDSv2 hop count on the EKS node launch template, which blocked pod access to instance metadata.
- Non-ASCII characters in the bastion cloud-init payload.
- Sumo Logic account-type designator and related issues (#1, #2, #3, #4, #6).

[Unreleased]: https://github.com/jeff-d/quicklab/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jeff-d/quicklab/releases/tag/v1.0.0
