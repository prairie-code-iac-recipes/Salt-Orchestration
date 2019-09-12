# Salt Orchestration Repository
## Purpose
This repository is responsible for managing saltmaster instances. It depends on the Salt Configuration Repository for the salt state files that are placed on each instance.

## Branching Model
### Overview
This repository contains definitions that need to follow an organization's environment model with changes deployed to non-production environments and tested before being deployed to the production environment.  To account for this I am using a branch-based deployment model wherein a permanent branch is created to represent each of the runtime environments supported by an organization. Terraform workspaces are created to mirror this approach so that state will be maintained at a branch/environment level.  The workspace is then used within the Terraform templates to assign environment-specific names to security groups, instances, DNS entries, etc.

### Detail
1. Modifications are made to feature branches created from the development branch.
2. Feature branches are then merged into the development branch via pull-request.
3. The development branch will automatically create/update saltmaster instances running in the development environment.
4. Once the change has been tested in the development environment they can be merged into the production branch.
5. The production branch will automatically create/update saltmaster instances running in the production environment when updated.

## Pipeline
1. All Terraform files will be validated whenever any branch is updated.
2. A Terraform Plan is run and the plan persisted whenever the development or production branches change.
3. A Terraform Apply is run for the persisted plan whenever the development or production branches change.

## Terraform
## Inputs
| Variable | Description |
| -------- | ----------- |
| ssh_username | The user that we should use for ssh connections.
| ssh_private_key | The contents of a base64-encoded SSH private key to use for the connection. |

## Processing
1. Uses AWS data providers to retrieve VPC, subnet, and DNS zone identifiers for use in downstream resources.
2. Creates a saltmaster instance-specific security group to enable restricted inbound access to SSH and ZeroMQ as well as unrestricted outbound access.
3. Creates one or more saltmaster instances from the CentOS Golden Image created by Packer.
4. Creates a Route53 health check for each instance and assigns it to a common load-balanced Route53 record.
5. Creates a separate Route53 record for each unique instance name.
6. Uses the "migrate_top" and "migrate_all_states" modules from the Salt Configuration repository to create/update the salt state tree on each instance.
7. Bootstraps the saltmaster service on each instance.

## Outputs
None
