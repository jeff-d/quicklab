these docs best viewed in a [browser](https://github.com/simov/markdown-viewer) as they contain hyperlinks and images.

# QuickLab

```
_______       _____      ______ ______        ______
__  __ \___  ____(_)________  /____  / ______ ___  /_
_  / / /  / / /_  /_  ___/_  //_/_  /  _  __ `/_  __ \
/ /_/ // /_/ /_  / / /__ _  ,<  _  /___/ /_/ /_  /_/ /
\___\_\\__,_/ /_/  \___/ /_/|_| /_____/\__,_/ /_.___/

```

Quickly create simple monitored lab environments.

QuickLab creates its components in AWS and uses [Sumo Logic](https://www.sumologic.com/) for monitoring. All QuickLab coponents are managed using [Terraform](https://www.terraform.io/).

Each QuickLab may include three infrastructure components:

- a private Network
- a Bastion host (virtual machine)
- a managed kubernetes Cluster

QuickLab is for builders and tinkerers who want to experiment with tech but avoid the pre-work required to build a playground that's secure, cost-effective, and minimally-viable enough for a variety of projects. QuickLab aims to automate laying that pre-work foundation on which builders can build and learners can learn.

QuickLab is designed to create lab _infrastructure_ only (and only the above-listed components). Once a QuickLab is created, it is up to the user to deploy _applications_ or create additional lab resources.

QuickLab's design philiosophy aims to balance two competing goals:

- minimalism, which promotes maintainability and cost-optimization
- a "batteries-included" user experience, which doesn't require the QuickLab user to understand the internals of its underlying technologies (e.g. terraform, AWS, Kubernetes, and Sumo Logic).

## Use Cases

1. Use the Bastion to securely access [Windows or Linux servers](docs/servers.md) in the Network's private subnets.
2. Use the Cluster to deploy and use containerized microservice-based apps like the [AstronomyShop application](astroshop.md).
3. Use Sumo Logic to analyze QuickLab component health, performance, cost, and security using out-of-box [solutions](docs/monitoring.md#app-catalog-apps) with no configuration required.
4. Use Sumo Logic to implement OpenTelemetry-based telemetry collection for logs, metrics, and traces to an [Observability backend](https://opentelemetry.io/docs/what-is-opentelemetry/).

**Bonus:** Anything else you might build on top of the above components! Once your Network with Bastion and/or Cluster are created you can use them to create any number of scenarios that call for a VM or a kubernetes cluster!

## Diagram

![QuickLab AWS](docs/quicklab-aws.png)
_QuickLab on AWS, showing all components enabled, including the Network (VPC), Bastion (EC2 Instance), Cluster (EKS) and Mointoring (Sumo Logic)_

## Documentation

- [Requirements](docs/requirements.md)
- [Usage](docs/usage.md)
- [Working with QuickLab Components](docs/components.md)
- [Private Servers](docs/servers.md)
- [Sumo Logic Astronomy Shop](docs/astroshop.md)
- [QuickLab Monitoring](docs/monitoring.md)
- [Project Notes](docs/notes.md)
