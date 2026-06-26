# WordPress cloud architecture 01: simple monolith

This is a single-server architecture:

- One EC2 instance in a public subnet, running WordPress' web server and database as well as storing its media files.

![diagram](../diagrams/wp01_simple_monolith.png)

## Pros

- Since it runs on virtualized infrastructure, there is no physical infrastructure to purchase/lease/maintain.
- It can be fairly quickly reprovisioned as a larger instance if required (vertical scaling).

## Cons

- Extremely limited resilience: the EC2 instance will become completely unavailable during any outages that bring down its Availability Zone.

  The app's functionality will also be interrupted if there is a major failure on its EC2 Host machine at AWS. A failure of the EC2 instance brings down a web server, a database, and a filesystem all at once, making the website unresponsive and possibly corrupting its data.
- Tightly coupled components (web server, database, and file storage) mean that none of them can be scaled independently of the others.
- Vertical scaling on EC2 can quickly get expensive; horizontal scaling is preferred.

All of the cons will be addressed as the architecture moves through different phases.
