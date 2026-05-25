# Base Infrastructure

The OpenTofu / Terraform code in this module builds a multi-tiered, multi-AZ VPC in the AWS `us-west-2` Region.

## Contents

- One `/16` non-default VPC, divided into 12 equally-sized subnets
- 4 subnets in each Availability Zone:
  - 3 private subnets
  - 1 publicly routable (web) subnet, with the required IGW / route tables / rt associations, and auto-assign enabled for public IPv4 addresses
- 3 Availability Zones
