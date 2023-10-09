these docs best viewed in a [browser](https://github.com/simov/markdown-viewer) as they contain hyperlinks and images.

# QuickLab Requirements

## Requirements

### General

- terraform (`brew install terraform`) : used to create QuickLab components
- [aws cli v2](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) (`brew install awscli`) : used to initialize Terraform's AWS Provider
  - [Quick configure](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/index.html) with `aws configure`
- cloud provider access keys : authenticates terraform to a cloud provider so it can manage QuickLab components
  - AWS: [Managing access keys for IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey)

### Bastion

- ssh client : used to connect to your Bastion

### Cluster

- [aws cli v2](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html) (`brew install awscli`) : used to create Cluster kubeconfig, and to verify status of Cluster-managed Application Load Balancers
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) (`brew install kubernetes-cli`) : used to manage the Cluster and kubeconfig
- [helm](https://helm.sh/) (`brew install helm`) : used to enable the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.5/)

  _Note: The AWS Load Balancer Controller makes it easy to expose apps publicly._

### Monitoring

- Sumo Logic:

  - [free account](https://www.sumologic.com/sign-up/) : used to analyze telemetry collected from your lab resources, perpetually free accounts are available

  - [curl](https://curl.se/) : used to install Sumo Logic [App Catalog](https://help.sumologic.com/docs/integrations/) apps
  - [helm](https://helm.sh/) (`brew install helm`) : used by QuickLab users to install the [Sumo Logic Kubernetes Solution](https://help.sumologic.com/docs/observability/kubernetes/quickstart/). This is NOT performed automatically by QuickLab on the Cluster, even when `monitoring = sumo`.

## Recommendations

While the below are not needed, they may make some advanced scenarios or troubleshooting easier.

- [Markdown Viewer](https://github.com/simov/markdown-viewer) : a browser extension for viewing markdown documents, with support for images and hyperlinks
- [Homebrew](https://brew.sh/) : a package manager for Mac OS which can be used to install the tools used by QuickLab via `brew install`
- [direnv](https://direnv.net/) (`brew install direnv`) : a shell extension for using directory-specific environment variables, which [can be used](https://developer.hashicorp.com/terraform/cli/config/environment-variables) to keep API keys out of terraform
- [GraphViz](https://graphviz.org/) (`brew install graphviz`) : can be used when generating an image of the [terraform graph](https://developer.hashicorp.com/terraform/cli/commands/graph#generating-images)
- [jq](https://jqlang.github.io/jq/) (`brew install jq`) : lightweight cli json processor
- [yq](https://kislyuk.github.io/yq/) (`brew install yq`) : cli tool for working with yaml

## Terraform Providers

Upon `terraform init`, QuickLab will download the following terraform providers:

```
terraform providers

Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/random] ~> 3.5
├── provider[registry.terraform.io/hashicorp/null] ~> 3.2
├── provider[registry.terraform.io/sumologic/sumologic] ~> 2.23
├── provider[registry.terraform.io/hashicorp/local] ~> 2.4
├── provider[registry.terraform.io/hashicorp/tls] ~> 4.0
├── provider[registry.terraform.io/hashicorp/time] ~> 0.9
├── provider[registry.terraform.io/hashicorp/cloudinit] ~> 2.3
├── provider[registry.terraform.io/hashicorp/http] ~> 3.3
├── provider[registry.terraform.io/hashicorp/aws] ~> 5.0
├── module.bastion
│   ├── provider[registry.terraform.io/sumologic/sumologic] ~> 2.22
│   ├── provider[registry.terraform.io/hashicorp/aws]
│   └── provider[registry.terraform.io/hashicorp/cloudinit]
├── module.cluster
│   ├── provider[registry.terraform.io/hashicorp/http]
│   ├── provider[registry.terraform.io/hashicorp/tls]
│   ├── provider[registry.terraform.io/hashicorp/aws]
│   ├── provider[registry.terraform.io/hashicorp/null]
│   └── provider[registry.terraform.io/hashicorp/local]
├── module.network
│   ├── provider[registry.terraform.io/hashicorp/local]
│   ├── provider[registry.terraform.io/hashicorp/tls]
│   └── provider[registry.terraform.io/hashicorp/aws]
└── module.sumo
    ├── provider[registry.terraform.io/sumologic/sumologic] ~> 2.22
    ├── provider[registry.terraform.io/hashicorp/aws]
    ├── provider[registry.terraform.io/hashicorp/null]
    ├── provider[registry.terraform.io/hashicorp/local]
    └── provider[registry.terraform.io/hashicorp/time]

Providers required by state:

    provider[registry.terraform.io/sumologic/sumologic]

    provider[registry.terraform.io/hashicorp/cloudinit]

    provider[registry.terraform.io/hashicorp/http]

    provider[registry.terraform.io/hashicorp/local]

    provider[registry.terraform.io/hashicorp/random]

    provider[registry.terraform.io/hashicorp/tls]

    provider[registry.terraform.io/hashicorp/aws]

    provider[registry.terraform.io/hashicorp/null]

    provider[registry.terraform.io/hashicorp/time]
```

---

## Documentation

- [README](../README.md)
- [Requirements](requirements.md)
- [Usage](usage.md)
- [Working with QuickLab Components](components.md)
- [Private Servers](servers.md)
- [Sumo Logic Astronomy Shop](astroshop.md)
- [QuickLab Monitoring](monitoring.md)
- [Project Notes](notes.md)
