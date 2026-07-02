# WordPress cloud architectures

The purpose of this repository is working through the process of breaking a basic, monolithic cloud infrastructure into a much more flexible design. Fully inspired by this project <https://github.com/acantril/learn-cantrill-io-labs/tree/master/aws-elastic-wordpress-evolution>, I thought I'd try my hand at writing the whole thing in OpenTofu/Terraform. Each architecture along the way will be written as its own root TF module.

Note that these designs are somewhat simplified for conceptual focus, so are not intended for production use.

## 1. [Simple monolith](./01_simple_monolith/)

This is a basic design with some serious limitations, but it is a quick starting point for an organization wanting to run a WordPress-based application on the cloud.

## 2. [Two-tier](./02_two_tier/)

This is an incremental improvement over the monolithic design. The database is migrated off of the monolith and implemented as a separate architectural tier using RDS.
