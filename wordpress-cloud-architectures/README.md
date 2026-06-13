# WordPress cloud architectures

The purpose of this repository is working through the process of breaking a basic, monolithic cloud infrastructure into a much more flexible design. Fully inspired by this project <https://github.com/acantril/learn-cantrill-io-labs/tree/master/aws-elastic-wordpress-evolution>, I thought I'd try my hand at writing the whole thing in OpenTofu/Terraform. Each architecture along the way will be written as its own root TF module.

Note that these designs are somewhat simplified for conceptual focus, so are not intended for production use.

## [01_simple_monolith](./01_simple_monolith/)

This is a basic design with some serious limitations, but it is a quick starting point for an organization wanting to run a WordPress-based application on the cloud.

It is a single-server architecture:

- One EC2 instance in a public subnet, running WordPress' web server and database as well as storing its media files.

### Pros

- Since it runs on virtualized infrastructure, there is no physical infrastructure to purchase/lease/maintain.
- It can be fairly quickly reprovisioned as a larger instance if required (vertical scaling).

### Cons

- Extremely limited resilience: the EC2 instance will become completely unavailable during any outages that bring down its Availability Zone. The app's functionality will also be interrupted if there is a major failure on its EC2 Host machine at AWS. A failure of the EC2 instance brings down a web server, a database, and a filesystem all at once, making the website unresponsive and possibly corrupting its data.
- Tightly coupled components (web server, database, and file storage) mean that none of them can be scaled independently of the others.
- Vertical scaling on EC2 can quickly get expensive; horizontal scaling is preferred.

All of the cons will be addressed as the architecture moves through different phases.
