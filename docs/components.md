these docs best viewed in a [browser](https://github.com/simov/markdown-viewer) as they contain hyperlinks and images.

# Working with QuickLab Components

## Cycle Times

| Component       | Enable | Disable |
| --------------- | ------ | ------- |
| Network         | < 5m   | < 5m    |
| Bastion         | < 2m   | < 2m    |
| Cluster         | < 15m  | < 15m   |
| Sumo Collection | < 5m   | < 5m    |

## Network

- Your workstation's public IP address is automatically added to Security Group rules to enable SSH to the Bastion and HTTPS access to the Cluster endpoint. If your workstation public IP changes, run `terraform apply` to restore your network access.
- For remote access from additional networks, edit `aws.auto.tfvars` and locate the `QuickLab Remote Access` section. Add one or more CIDRs to the `remoteaccesscidrs` string list to have them referenced by the Network's Security Group rules.

## Bastion

- The Bastion is provisioned using differnet user data if Sumo Collection is enabled vs disabled. As a result, toggling `monitoring` while `create_bastion=true` forces Bastion replacement.

- Add Basion's SSH Key to your known_hosts file using `eval $(terraform output -raw bastion_known_hosts)`.

- Connect to Bastion using `ssh` using `eval $(terraform output -raw bastion_connect)`.

- The SSH keypair used by the Bastion should be used when launching other EC2 instances in the QuickLab Network's public and private subnets.

- Use the included `ssh-config` file proxyjump to your private EC2 instance via the Bastion with a command like `ssh -F $(terraform output -raw bastion_ssh_config) $server` where `$server` interpolates to:

  ```
  # requires jq
  # run command from the terraform project directory (e.g. `quicklab/aws`) to reference terraform output values

  vpcid=$(terraform output -raw network_id) && sgid=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$vpcid Name=group-name,Values=bastion-remote-access-ssh --query "SecurityGroups[*].GroupId" --output text) && LabId=$(terraform output -raw _lab_id) && now=$(date "+%F-%M%S") && Name="server-$now" && server=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --key-name $(terraform output -raw network_ssh_keyname) \
  --count 1 \
  --subnet-id $(terraform output -json network_priv_subnets | jq -r '.[0]') \
  --security-group-ids $sgid \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$Name}, {Key=LabId,Value=$LabId}, {Key=CreatedWith,Value=aws-cli}]" \
  --query 'Instances[*].{PrivateDnsName:PrivateDnsName}' \
  --output text) && printf "%s\n" "server: $server"
  ```

- To avoid blindly trusting the bastion's public key fingerprint on first connection, consider updating `known_hosts` using the provided terraform output prior to first connection, or add `StrictHostKeyChecking false` to `~/.ssh/config` for hosts with public dns names ending with `*.amazonaws.com`.

- To disable `StrictHostKeyChecking` for a single connection, use `ssh` options like `StrictHostKeyChecking=no`, `UserKnownHostsFile=/dev/null`, and `GlobalKnownHostsFile=/dev/null`. For example: `eval $(echo $(terraform output -raw bastion_connect) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null)`

- The Bastion is a t3.micro created from the [latest Amazon Linux 2023 x86_x64 AMI](https://docs.aws.amazon.com/linux/al2023/ug/get-started.html) (e.g. `al2023-ami-kernel-default-x86_64`). GitHub: [Amazon Linux 2023](https://github.com/amazonlinux/amazon-linux-2023)

- You can find the regional AMI ID used for your Bastion by querying the public SSM Parameter like this: `aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`

- Amazon Linux 2023's [default SSH server configuration](https://docs.aws.amazon.com/linux/al2023/ug/ssh-host-keys-disabled.html) is described in the AWS documentation.

## Cluster

- Enable QuickLab kubeconfig using `eval $(terraform output -raw cluster_kubeconfig)`. This updates your $KUBECONFIG path list with the locaiton of the QuickLab Cluster's kubeconfig file.
- Get QuickLab Cluster info using `kubectl cluster-info`
- Get Cluster pods from all Namespaces using `kubectl get pods -A -o wide`
- Get all Cluster resources from all Namespaces using `kubectl get all -A`

  _Notes:_

  - _application deployments_

    - _Follow the Sumo Logic Astronomy Shop [walkthrough](astroshop.md) to deploy the included Open Telemetry demo application_

    - _Use standard techniques to deploy other applications, including via Helm (`helm upgrade -i release-name repo/chart`) or kubectl (`kubectl apply -f app-manifest.yaml`)_

    - _Another good demo application is The Coffee Bar App (see external documentation at [the-coffee-bar repo](https://github.com/SumoLogic/the-coffee-bar) for details)._

  - _kubeconfig management_

    - _Upon cluster creation, terraform will create a new kubeconfig at `~/.kube/<CLUSTER-NAME>`and any existing path list in `$KUBECONFIG` is backed up to `~/.kube/kubeconfig-original.txt`. To add the QuickLab kubeconfig to `$KUBECONFIG`, use the suggested command: `eval $(terraform output -raw cluster_kubeconfig)`._

    - _Because the file `~/.kube/config` is unmodified, the default kubectl config and context are unaltered for other shells, and will not persist terminating the shell used to run `terraform apply`._

    - _You can access the cluster by explicitly specifying the quicklab kubeconfig (e.g. `kubectl cluster-info --kubeconfig=~.kube/$(terraform output -raw cluster_name)`) or by updating the `$KUBECONFIG` environment variable (e.g. `export KUBECONFIG=${KUBECONFIG}:~/.kube/$(terraform output -raw cluster_name)`)_

    - _Upon cluster deletion, terraform will remove the quicklab kubeconfig file (using `rm ~/.kube/<CLUSTER-NAME>`)._

## Monitoring

- Set `monitoring` to `sumo` (see the `QuickLab Components` section in `aws.auto.tfvars`) to have QuickLab automatically collect telemetry from the Network, Bastion, and Cluster.

- the [Sumo Logic Kubernetes Solution](https://help.sumologic.com/docs/observability/kubernetes/quickstart/) is NOT automatically installed on the Cluster, even when `monitoring = sumo`, as it is already included when using the Astronomy Shop demo application.

- QuickLab will create configuration and content in your Sumo Logic organization. If these items already exist in your Sumo Logic organization, you will see related terraform errors.

  _Note: See [QuickLab Monitoring](monitoring.md) for full details on QuickLab's out-of-box monitoring use cases, and the Sumo Logic configuration and content items QuickLab creates._

## Documentation

- [README](../README.md)
- [Requirements](requirements.md)
- [Usage](usage.md)
- [Working with QuickLab Components](components.md)
- [Private Servers](servers.md)
- [Sumo Logic Astronomy Shop](astroshop.md)
- [QuickLab Monitoring](monitoring.md)
- [Project Notes](notes.md)
