[comment]: # "This file is part of QuickLab, which creates simple, monitored labs."
[comment]: # "https://github.com/jeff-d/quicklab"
[comment]: #
[comment]: # "SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>"
[comment]: # "SPDX-License-Identifier: AGPL-3.0-or-later"

# QuickLab Components

## Cycle Times

| Component               | Enable | Disable |
| ----------------------- | ------ | ------- |
| network                 | < 5m   | < 5m    |
| bastion                 | < 2m   | < 2m    |
| cluster                 | < 15m  | < 15m   |
| monitoring (Sumo Logic) | < 5m   | < 5m    |

## Network

- Your workstation's public IP address is automatically added to Security Group rules to enable SSH to the bastion and HTTPS access to the cluster endpoint. If your workstation public IP changes, run `terraform apply` to restore your network access.
- For remote access from additional networks, edit `aws.auto.tfvars` and locate the `Remote Access` section. Add one or more CIDRs to the `remoteaccesscidrs` string list to have them referenced by the network's Security Group rules.

## Bastion

- Use the bastion to securely connect to [private servers](servers.md).

- The bastion is a t3.micro created from the [latest Amazon Linux 2023 x86_x64 AMI](https://docs.aws.amazon.com/linux/al2023/ug/get-started.html) (e.g. `al2023-ami-kernel-default-x86_64`).

- The bastion is provisioned using differnet user data if monitoring (Sumo Logic) is enabled vs disabled. As a result, toggling `monitoring` while `create_bastion=true` forces bastion replacement.

- Add Basion's SSH Key to your known_hosts file using `eval $(terraform output -raw bastion_known_hosts)`.

- To avoid blindly trusting the bastion's public key fingerprint on first connection, consider updating `known_hosts` using the provided terraform output prior to first connection, or add `StrictHostKeyChecking false` to `~/.ssh/config` for hosts with public dns names ending with `*.amazonaws.com`.

- To disable `StrictHostKeyChecking` for a single connection, use `ssh` options like `StrictHostKeyChecking=no`, `UserKnownHostsFile=/dev/null`, and `GlobalKnownHostsFile=/dev/null`. For example: `eval $(echo $(terraform output -raw bastion_connect) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null)`

- Full details on Amazon Linux 2023 default SSH server configuration are in the [AWS documentation](https://docs.aws.amazon.com/linux/al2023/ug/ssh-host-keys-disabled.html).

## Cluster

- Included addons: [Amazon EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- Enable QuickLab kubeconfig using `eval $(terraform output -raw cluster_kubeconfig)`. This updates your $KUBECONFIG path list with the locaiton of the QuickLab cluster's kubeconfig file.

  _Notes:_

  - _application deployments_

    - _Use standard techniques to deploy other applications, including via Helm or kubectl_

    - _Follow the Sumo Logic Astronomy Shop [walkthrough](astroshop.md) to deploy the included Open Telemetry demo application_

  - _kubeconfig management_

    - _Upon cluster creation, terraform will create a new kubeconfig at `~/.kube/<CLUSTER-NAME>`and any existing path list in `$KUBECONFIG` is backed up to `~/.kube/kubeconfig-original.txt`. To add the QuickLab kubeconfig to `$KUBECONFIG`, use the suggested command: `eval $(terraform output -raw cluster_kubeconfig)`._

    - _Because the file `~/.kube/config` is unmodified, the default kubectl config and context are unaltered for other shells, and will not persist terminating the shell used to run `terraform apply`._

    - _You can access the cluster by explicitly specifying the quicklab kubeconfig (e.g. `kubectl cluster-info --kubeconfig=~.kube/$(terraform output -raw cluster_name)`) or by updating the `$KUBECONFIG` environment variable (e.g. `export KUBECONFIG=${KUBECONFIG}:~/.kube/$(terraform output -raw cluster_name)`)_

    - _Upon cluster deletion, terraform will remove the quicklab kubeconfig file (using `rm ~/.kube/<CLUSTER-NAME>`)._

## Monitoring

- Set `monitoring` to `sumo` (see the `Components` section in `aws.auto.tfvars`) to have QuickLab automatically collect telemetry from the network, bastion, and cluster.

- QuickLab will create configuration and content in your Sumo Logic organization. If these items already exist in your Sumo Logic organization, you will see related terraform errors. See [QuickLab Monitoring](monitoring.md) for full details.

- the [Sumo Logic Kubernetes Solution](https://help.sumologic.com/docs/observability/kubernetes/quickstart/) is NOT automatically installed on the cluster, even when `monitoring = sumo`, as it is already included when using the Astronomy Shop demo application.

## Documentation

- [Requirements](requirements.md)
- [Usage](usage.md)
- [Components](components.md)
- [About](about.md)
