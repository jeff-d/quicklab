[comment]: # "This file is part of QuickLab, which creates simple, monitored labs."
[comment]: # "https://github.com/jeff-d/quicklab"

# QuickLab Versioning

QuickLab releases follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`, tagged `vX.Y.Z`.

For most software, SemVer's "public API" is a set of function signatures. QuickLab is terraform, so its
public API is different — and knowing exactly what it covers is what makes a version number useful.

## What QuickLab Versions

A QuickLab version is a promise about four things:

1. **Terraform state layout** — the addresses Terraform tracks your lab under in its state file (for
   example, `module.cluster["<labid>"].aws_eks_cluster.this`).
2. **Root inputs and outputs** — the variables in `aws/variables.tf` (and therefore the keys you set in
   `aws.auto.tfvars`) and the outputs in `aws/outputs.tf`.
3. **Tooling floor** — `required_version`, provider version constraints, and the required CLIs listed in
   [Requirements](requirements.md).
4. **Script CLIs** — the flags accepted by the companion shell scripts under `aws/modules/`
   (`create-server.sh`, `delete-server.sh`, `app.sh`, `astroshop.sh`, `lb.sh`).

What a version does _not_ promise is that the cloud objects behind those addresses survive an upgrade.
An address is a name in your state file; the EKS cluster or EC2 instance it names may be destroyed and
recreated with new IDs. A lab is disposable infrastructure, so that is a normal consequence of an
upgrade, not a breaking change — see below.

## Major, Minor, Patch

| Bump      | Means                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **MAJOR** | Backward compatibility is a goal for all releases, but `git pull && terraform apply` is not guaranteed to work on a running lab, so state surgery (`terraform state mv`, `import`, or `rm`) **may** be required. The **MAJOR** release designator will be used when: Module or resource addresses move; a root variable or output is removed or renamed; the `required_version` floor has been raised; a component (or `monitoring` backend) has been removed; helper script flags change incompatibly. **In most cases the easiest path is `terraform destroy` on the existing lab before pulling the new version.** Labs are disposable, and recreating one is usually less work than migrating state. |
| **MINOR** | Additive. `terraform apply` absorbs it. A new component, a new `monitoring` value, a new variable _with a default_, a new output, new Sumo Logic apps/fields/field extraction rules, new EKS addons, new scripts or walkthroughs. **This includes changes that force resource replacement.**                                                                                                                                                                                                                                                                                                                                                                                                             |
| **PATCH** | No interface change at all. Bug fixes, documentation, provider or addon version bumps inside existing constraints, lock file refreshes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

The rule in one line: **resource replacement is MINOR; state surgery is MAJOR.**

Terraform recreating cloud resources is automatic, expected, and the normal cost of running a lab.
Hand-editing your state file is none of those things. The distinction is what the version number is for.

## Apply Impact Annotations

Because "will this apply cleanly?" is never answerable from a commit subject, every entry in
[CHANGELOG.md](../CHANGELOG.md) is annotated with its apply impact:

| Annotation        | What happens when you upgrade and apply                                                    |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `no-op`           | Nothing changes in your infrastructure. Docs, comments, or CI only.                        |
| `in-place`        | Terraform updates existing resources without destroying them.                              |
| `replacement`     | Terraform destroys and recreates one or more cloud resources. Expect downtime and new IDs. |
| `state migration` | You must run `terraform state` commands by hand before applying. Steps will be documented. |

Read the annotations before upgrading. A `replacement` on a lab you are actively using is worth knowing
about in advance; a `state migration` is worth reading twice.

## Upgrading Between Versions

For MINOR and PATCH releases:

```
git pull
cd aws
terraform apply
```

Review the plan before confirming, particularly for anything annotated `replacement`.

For MAJOR releases, read that version's section in the release notes first. Then pick one of two paths:

**Start fresh (recommended).** Destroy the existing lab on the old version, then upgrade:

```
cd aws
terraform destroy
git pull
terraform apply
```

This sidesteps state migration entirely, and for disposable infrastructure it is usually the lower-effort
choice.

**Keep the lab.** If you need to carry a running lab across, a MAJOR release that requires state migration
ships step-by-step instructions. Those steps always end with a `terraform plan` that reports **no
changes** — that is your proof the migration worked.

## Supported Versions

QuickLab is a single-maintainer project. Only the latest release is supported, and fixes land on `main`
for inclusion in the next release rather than being backported.

Releases are published at [github.com/jeff-d/quicklab/releases](https://github.com/jeff-d/quicklab/releases).

## Documentation

- [Requirements](requirements.md)
- [Usage](usage.md)
- [Components](components.md)
- [About](about.md)
