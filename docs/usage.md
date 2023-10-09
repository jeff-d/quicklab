these docs best viewed in a [browser](https://github.com/simov/markdown-viewer) as they contain hyperlinks and images.

# QuickLab Usage

## Lifecycle

![QuickLab Lifecycle](quicklab-lifecycle.png)

## Walkthrough

### Prerequisites

- create API keys (for [cloud provider](requirements.md#general) and [monitoring](requirements.md#monitoring))
- download [required](requirements.md) software
- add API keys to QuickLab for monitoring
  - Edit `aws.auto.tfvars`. In the `QuickLab TF providers` section, add Sumo Logic credentials.

_Notes:_

- _Terraform will automatically use your `default` aws cli profile to authenticate to AWS and select which Region to use, but you can optionally specify a different named aws cli profile and region._
- _Terraform can read your API keys from [environment variables](https://developer.hashicorp.com/terraform/language/values/variables#environment-variables)._

### Create

**This step validates you have met the prerequisites and is required before enabling QuickLab components.**

- initialize terraform from the root module (e.g. `quicklab/aws`) using `terraform init`.
- create empty QuickLab (with all components disabled) using `terraform apply -auto-approve` and review terraform output. It should be similar to:

  ```
  quicklab/aws $ terraform apply -auto-approve

  Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

  Outputs:

  _lab_id = "6eg4"
  _lab_resource_group = "quicklab-6eg4-resources"
  aws_caller = "arn:aws:iam::111111111111:user/username"
  aws_region = "us-east-2"

  ```

  _Note: `terraform apply` can be used without `-auto-approve` to review the tf plan before terraform implements it._

### Use

Enable the QuickLab components needed for your use case, starting with the Network (which is required for the Bastion and Cluster). Disable QuickLab components when they are no longer needed.

- enable or disable a component

  - Edit `aws.auto.tfvars`. In the `QuickLab Components` section, set `create_network` to `true` (or `false`).
  - Update QuickLab using `terraform apply -auto-approve` and review terraform output.

- enable or disable monitoring

  - Edit `aws.auto.tfvars`. In the `QuickLab Components` section, set `monitoring` to `sumo` (or `none`).
  - Update QuickLab using `terraform apply -auto-approve` and review terraform output.

- build on QuickLab

  - launch Windows or Linux virtual machines into the Network
  - deploy and use additional network infrastructure like AWS Network Firewall, or Gateway Load Balancer
  - install containerized applications on the Cluster
  - install and use software packages on the Bastion (or other Virtual Machines you create)

_Notes:_

- _See a QuickLab inventory in the [AWS Console](https://console.aws.amazon.com/resource-groups/) using the `_lab_resource_group` named in the terraform output._
- _For typical QuickLab component create/destroy times, see [component notes](component-notes.md#resource-createdestroy-times)._
- _When building on QuickLab, remember that any resources you create or add will not be managed by QuickLab's terraform state. These resources should be removed prior to disabling any QuickLab component they depend on._

### Destroy

- destroy QuickLab

  - Use `terraform destroy` to reset the Lab Id and clear Terraform state.
  - To remove all QuickLab components while maintaining the existing Lab Id, use:

    ```
    terraform apply \
    -auto-approve \
    -var="create_network=false" \
    -var="create_bastion=false" \
    -var="create_cluster=false" \
    -var="monitoring=none"
    ```

    _Note: terraform [variables can be set](https://developer.hashicorp.com/terraform/language/values/variables#assigning-values-to-root-module-variables) for each run via cli argument_

## Documentation

- [README](../README.md)
- [Requirements](requirements.md)
- [Usage](usage.md)
- [Working with QuickLab Components](components.md)
- [Private Servers](servers.md)
- [Sumo Logic Astronomy Shop](astroshop.md)
- [QuickLab Monitoring](monitoring.md)
- [Project Notes](notes.md)
