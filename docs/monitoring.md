[comment]: # "This file is part of QuickLab, which creates simple, monitored labs."
[comment]: # "https://github.com/jeff-d/quicklab"
[comment]: #
[comment]: # "SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>"
[comment]: # "SPDX-License-Identifier: AGPL-3.0-or-later"

# QuickLab Monitoring: Sumo Logic

## Account Types

QuickLab's `sumo` module is designed for Sumo Logic Cloud Flex Credits accounts, and assumes an account type of "Free" by default. Users can indicicate their use of a different `sumo_accounttype` in `aws.auto.tfvars` to have QuickLab enable certain [other features](https://help.sumologic.com/docs/manage/manage-subscription/cloud-flex-credits-accounts/#features-by-subscription-type) not available to Sumo Logic Free users. Valid values for `sumo_accounttype` include "Free", "Trial", "Essentials", "Enterprise Operations", "Enterprise Security", and "Enterprise Suite".

## Authentication

Due to terraform provider design, the Sumo Logic Terraform Provider must be configured, whether or not you plan to collect data into Sumo Logic. By default, placeholder values are used.

The Terraform Provider references terraform variables, which can be set by exporting environment variables or in aws.auto.tfvars. For example:

```
quicklab/aws $ vim aws.auto.tfvars

# OR

quicklab/aws $  export TF_VAR_sumo_accessid=my-access-id
quicklab/aws $  export TF_VAR_sumo_accesskey=my-access-key
quicklab/aws $  export TF_VAR_sumo_env=us1
quicklab/aws $  export TF_VAR_sumo_org=000000000000000B
```

## Fields & Extractions

Sumo Logic [Field Extractions](https://help.sumologic.com/docs/manage/field-extractions/) can dynamically parse and assign values to Fields at ingest-time. QuickLab creates two Field Extraction Rules:

- AWS Cost Explorer
- VPC Flow Logs

By default QuickLab attempts to create (and manage) the Fields needed to satisfy supported Sumo Logic use cases. In cases where a Field Extraction Rule scope references a field that doesn't exist, this field will need to be created first. For example:

```
╷
│ Error: {"id":"N9S4I-MUP4W-REV65","errors":[{"code":"fer:invalid_extraction_rule","message":"Invalid Field Extraction Rule","meta":{"reason":"Invalid scope: account = * region CostUsd CostType StartDate EndDate MetricType Granularity Service LinkedAccount"}}]}
│
│   with module.sumo["vznw"].sumologic_field_extraction_rule.costexplorer["aws"],
│   on modules/sumo/costexplorer.tf line 83, in resource "sumologic_field_extraction_rule" "costexplorer":
│   83: resource "sumologic_field_extraction_rule" "costexplorer" {
│
```

Sumo Logic [Fields](https://help.sumologic.com/docs/manage/fields/) are metadata (key-value pairs) that get applied to ingested telemetry and are used to query and filter signals. The following Sumo Logic use cases require certain Fields to be present. By default QuickLab attempts to create and manage these Fields, but exposes flags in `aws.auto.tfvars` to disable this behavior for cases where these Fields already exist.

- AWS Cost Explorer: "account", "linkedaccount"
- AWS resource tags: "labid", "prefix", "owner", "environment", "project", "createdby", "createdfor", "createdwith"
- AWS VPC Flow Logs: "version", "accountID", "interfaceID", "src_ip", "dest_ip", "src_port", "dest_port", "Protocol", "Packets", "bytes", "StartSample", "EndSample", "Action", "status"
- QuickLab bastion (OpenTelemetry Collector): "host.group", "deployment.environment", "host.name", "host.id", "os.type", "cloud.provider", "cloud.platform", "cloud.account.id", "cloud.region", "cloud.availability_zone", "host.image.id", "host.type"

If these tags already exist in the target Sumo Logic organization, Sumo Logic will return a `field:already_exists` error to terraform.

For example:

```
╷
│ Error: {"id":"S3Q7E-3EQS9-S3A4T","errors":[{"code":"field:already_exists","message":"Field with the given name already exists"}]}
│
│   with module.sumo["vznw"].sumologic_field.costexplorer["linkedaccount"],
│   on modules/sumo/costexplorer.tf line 73, in resource "sumologic_field" "costexplorer":
│   73: resource "sumologic_field" "costexplorer" {
│
╵
╷
│ Error: {"id":"UHPFY-Q7F2R-P1Z96","errors":[{"code":"field:already_exists","message":"Field with the given name already exists"}]}
│
│   with module.sumo["vznw"].sumologic_field.tags["owner"],
│   on modules/sumo/main.tf line 25, in resource "sumologic_field" "tags":
│   25: resource "sumologic_field" "tags" {
│
╵
```

## App Catalog

Each App in the Sumo Logic [App Catalog](https://help.sumologic.com/docs/integrations/) has it's own prerequisites, typically including:

- creating AWS account resources to send the logs
- creating Sumo Org resources to receive the logs
- installing a Sumo App to visualize the logs on a dashboard

QuickLab automatically installs the following Apps along with their required AWS and Sumo Org resources:
| App | Installed When | Notes |
|----------------------------|--------------------------------------------------|-------------------------------------------------|
| [AWS CloudTrail](https://help.sumologic.com/docs/integrations/amazon-aws/cloudtrail/) | monitoring = sumo | enable 'admin user' list via below instructions |
| [AWS Cost Explorer](https://help.sumologic.com/docs/integrations/amazon-aws/cost-explorer/) | monitoring = sumo | Fields created; "account", "linkedaccount" |
| [Amazon VPC Flow Logs](https://help.sumologic.com/docs/integrations/amazon-aws/vpc-flow-logs/) | monitoring = sumo AND create_network = true | |
| [Amazon EKS - Control Plane](https://help.sumologic.com/docs/integrations/amazon-aws/eks-control-plane/) | monitoring = sumo AND create_cluster = true | |

## QuickLab+Sumo Logic Use Cases

QuickLab users can enable Sumo Logic collection without building any infrastructure which sends AWS logs to Sumo that are not specific to QuickLab components. When creating QuickLab components, enabling Sumo Logic telemetry collection provides visibility to what is happening in the network, bastion, and cluster, as explained below.

### AWS General

CloudTrail Logs

- This terraform module creates a new CloudTrail trail and accompanying S3 Bucket, and initiates collection to a [Sumo Logic CloudTrail Source](https://help.sumologic.com/docs/send-data/hosted-collectors/amazon-aws/aws-cloudtrail-source/).

- Collected logs are searchable using a query like `_sourceCategory = quicklab/LabId/aws/us-west-2/cloudtrail`

- The AWS CloudTrail App is installed to the Sumo Logic Library (in your personal folder) at "QuickLab/AWS CloudTrail/"

- The App's [User Monitoring](https://help.sumologic.com/docs/integrations/amazon-aws/cloudtrail/#aws-cloudtrail---user-monitoring) dashboard has three panels that track activity from AWS Admins. When using a Sumo Llogic [Account Type](#account-types) compatible with Lookup Tables, QuickLab automatically uploads a list of privileged AWS usernames to your Sumo Logic organization to demonstrate this functionality. To enable these panels on the User Monitoring dashboard, manually execute the search `QuickLab\update-aws-admins-list` to populate the list.

Cost Explorer

- Configured to pull in CE data from all AWS Regions (by leaving ['AWS Regions'](https://help.sumologic.com/docs/send-data/hosted-collectors/cloud-to-cloud-integration-framework/aws-cost-explorer-source/#json-configuration) unspecified)

- Collected logs are searchable using a query like `_sourceCategory = quicklab/LabId/aws/us-west-2/costexplorer`

- uses an [AWS Cost Explorer Source](https://help.sumologic.com/docs/integrations/amazon-aws/cost-explorer/)

- uses `aws_account_name` if specified in `aws.auto.tfvars`

### Network

VPC Flow Logs

- ports the [cloudformation-based solution](https://help.sumologic.com/docs/integrations/amazon-aws/vpc-flow-logs/#collecting-amazon-vpc-flow-logs-from-cloudwatch-using-cloudformation) for collecting VPC Flow Logs from a CloudWatch Log Group into a Sumo Logic organization.

- Collected logs are searchable using a query like `_sourceCategory = quicklab/LabId/aws/us-west-2/network/flowlogs`

- The Amazon VPC Flow Logs App is installed to the Sumo Logic Library (in your personal folder) at "QuickLab/Amazon VPC Flow Logs/"

### Bastion

otelcol-sumo config

- otelcol-sumo is installed on bastion via [Install Script](https://help.sumologic.com/docs/send-data/opentelemetry-collector/install-collector-linux/#install-script)
- collector customizations are created by cloud-init in `/etc/otelcol-sumo/conf.d/prefix-LabId-otelcol-sumo.yaml` which is picked up by otelcol-sumo on first run

QuickLab default telemetry sources

The following otel config files are created in `/etc/otelcol-sumo/conf.d/`:

```
sudo tree /etc/otelcol-sumo/conf.d/
/etc/otelcol-sumo/conf.d/
├── common.yaml
├── log-bootstrap.yaml
├── log-system.yaml
├── metrics-host.yaml
└── prefix-labid-otelcol-sumo.yaml
```

| File                             | CreatedBy                 | Purpose                          | Notes                                                                                                                                  |
| -------------------------------- | ------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| common.yaml                      | Sumo Logic Install Script | configure collector tags         |                                                                                                                                        |
| _prefix-labId_-otelcol-sumo.yaml | QuickLab cloud-init       | customizes the sumo collector    |                                                                                                                                        |
| log-bootstrap.yaml               | QuickLab cloud-init       | collects Instance bootstrap logs |                                                                                                                                        |
| log-system.yaml                  | QuickLab cloud-init       | collects system logs             | compatible with [ Linux App ](https://help.sumologic.com/docs/integrations/hosts-operating-systems/opentelemetry/linux-opentelemetry/) |
| metrics-host.yaml                | QuickLab cloud-init       | collects host metrics            | compatible with [ Linux App ](https://help.sumologic.com/docs/integrations/hosts-operating-systems/opentelemetry/linux-opentelemetry/) |

Custom telemetry sources

Additional otel config files can be placed in `/etc/otelcol-sumo/conf.d/` and will take affect at next otelcol-sumo restart (e.g. `systemctl restart otelcol-sumo`).

Refer to examples in the [sumologic-otel-collector-packaging](https://github.com/SumoLogic/sumologic-otel-collector-packaging/tree/main/assets/conf.d/examples) repo.

### Cluster

EKS Control Plane Logs

- Collected logs are searchable using a query like `_sourceCategory = quicklab/labid/aws/us-west-2/cluster/controlplane`

- Quicklab intentionally does NOT install or configure the Sumo Logic [Kubernetes Observability](https://help.sumologic.com/docs/observability/kubernetes/) solution. Once your Cluster is active, users can do this by running the `helm upgrade -i` command as per Sumo Logic documentation. Doing so will create a new Hosted Collector (with associated Sources).

- The below example gives the helm release the name `collection`, references a `repo/chart` of `sumologic/sumologic`, and creates kubernetes resources in a new namespace called `sumologic`. Sumo Logic credentials are furnished using environment variables.

  ```
  helm upgrade -i collection sumologic/sumologic \
  --namespace sumologic \
  --create-namespace \
  --set sumologic.accessId=$TF_VAR_sumo_accessid \
  --set sumologic.accessKey=$TF_VAR_sumo_accesskey \
  --set sumologic.clusterName=$(terraform output -raw cluster_name) \
  --set sumologic.collectorName=$(terraform output -raw cluster_name)
  ```

- To uninstall Sumo Logic collection: `helm uninstall collection -n sumologic` (and delete Hosted Collector manually)

## Documentation

- [Requirements](requirements.md)
- [Usage](usage.md)
- [Components](components.md)
- [About](about.md)
