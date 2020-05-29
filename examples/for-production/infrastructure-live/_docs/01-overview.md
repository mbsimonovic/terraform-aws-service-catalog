# Architecture Overview
 
This documentation contains an overview of the architecture deployed and managed in this repo.

First, the short version: 

- This is an end-to-end tech stack for [Amazon Web Services (AWS)](https://aws.amazon.com/) that incluldes all the
  basic infrastructure a company needs, including the network topology, orchestration tools (e.g., Kubernetes or ECS),
  databases, caches, load balancers, CI / CD pipeline, monitoring, alerting, log aggregation, etc.  
- It's all defined and managed as code using tools such as [Terraform](https://www.terraform.io/), 
  [Packer](https://www.packer.io/), and [Docker](https://www.docker.com/).
- It's built on top of the [Gruntwork Reference Architecture](https://www.gruntwork.io/reference-architecture/). 
  
Here's a diagram that shows a rough overview of what the Reference Architecture looks like:

![Architecture Diagram](_images/ref-arch-full.png)

Now, the long version:

1. [Infrastructure as code](#infrastructure-as-code)
1. [Environments](#environments)
1. [AWS accounts](#aws-accounts)
1. [VPCs and subnets](#vpcs-and-subnets)
1. [Load balancers](#load-balancers)
1. [Docker clusters (EKS)](#docker-clusters)
1. [Data stores](#data-stores)
1. [OpenVPN server](#openvpn-server)
1. [CircleCI](#circleci)
1. [Monitoring, log aggregation, alerting](#monitoring-log-aggregation-alerting)
1. [DNS and TLS](#dns-and-tls)
1. [Security](#security)




## Infrastructure as code

All of the infrastructure in this repo is managed as **code**, primarily using [Terraform](https://www.terraform.io/). 
That is, instead of clicking around a web UI or SSHing to a server and manually executing commands, the idea behind 
infrastructure as code (IAC) is that you write code to define your infrastructure and you let an automated tool (e.g.,
Terraform) apply the code changes to your infrastructure. This has a number of benefits:

* You can automate your entire provisioning and deployment process, which makes it much faster and more reliable than 
  any manual process.

* You can represent the state of your infrastructure in source files that anyone can read rather than a sysadmin's head.

* You can store those source files in version control, which means the entire history of your infrastructure is 
  captured in the commit log, which you can use to debug problems, and if necessary, roll back to older versions.

* You can validate each infrastructure change through code reviews and automated tests.

* You can package your infrastructure as reusable, documented, battle-tested modules that make it easier to scale and 
  evolve your infrastructure. In fact, much of the infrastructure code in this architecture is deployed from the 
  [Gruntwork Service Catalog](https://github.com/gruntwork-io/aws-service-catalog/).

For more info on Infrastructure as Code and Terraform, check out [A Comprehensive Guide to 
Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca).

  
  
  
## Environments

The infrastructure is deployed across multiple environments:

* **dev**: Sandbox environment.
* **stage**: Pre-production environment.
* **prod**: Production environment.
* **security**: All IAM users and permissions are defined in this account.
* **shared-services**: DevOps tooling.





## AWS accounts

The infrastructure is deployed across multiple AWS accounts. For example, the staging environment is in one account,
the production environment in another account, the DevOps tooling in yet another account, and so on. This gives you 
better isolation between environments so that if you break something in one environment (e.g., staging)—or worse yet, a 
hacker breaks into that environment—it should have no effect on your other environments (e.g., prod). It also gives you
better control over what resources each employee can access.

Check out the [Authentication docs](02-authenticate.md) for more info on how to authenticate to these accounts and 
switch between them.




## VPCs and subnets

Each environment lives in a separate [Virtual Private Cloud (VPC)](https://aws.amazon.com/vpc/), which is a logically 
isolated section within an AWS account. Each VPC defines a virtual network, with its own IP address space and rules for 
what can go in and out of that network. The IP addresses within each VPC are further divided into multiple 
[subnets](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Subnets.html), where each subnet controls the 
routing for its IP address. 

* *Public subnets* are directly accessible from the public Internet.
* *Private subnets* are only accessible from within the VPC.

Just about everything in this infrastructure is deployed in private subnets to reduce the surface area to attackers.
The only exceptions are load balancers and the [OpenVPN server](#openvpn-server), both of which are described below.

Each VPC is also configured with [VPC flow logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html), which
can be useful for monitoring and auditing network traffic across the VPC. Each VPC publishes its flow logs to CloudWatch
Logs, under the log group `VPC_NAME-vpc-flow-logs`, where the `VPC_NAME` is an input variable to the `vpc` module.

To learn more about VPCs and subnets, check out the Gruntwork [vpc
service](https://github.com/gruntwork-io/aws-service-catalog/tree/master/modules/networking/vpc).




## Load balancers

Traffic from the public Internet (e.g., requests from your users) initially goes to a *public load balancer*, which 
proxies the traffic to your apps. This allows you to run multiple copies of your application for scalability and high 
availability. The load balancers being used are:

* [Application Load Balancer (ALB)](https://aws.amazon.com/elasticloadbalancing/applicationloadbalancer/): The ALB is a
  load balancer managed by AWS that is designed for routing HTTP and HTTPS traffic. The advantage of using a managed
  service is that AWS takes care of fault tolerance, security, and scaling the load balancer for you automatically. 
  Note that in EKS, ALBs are managed by Kubernetes using `Ingress` resources. Check out the [eks-alb-ingress-controller
  documentation](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-alb-ingress-controller) for
  more information on how this works.



## Docker clusters

Application code is packaged into [Docker containers](http://docker.com/) and deployed across an Amazon [Elactic 
Kubernetes Service (EKS)](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) cluster. The advantage of 
Docker is that it allows you to package your code so that it runs exactly the same way in all environments (dev, stage, 
prod). The advantage of a Docker Cluster is that it makes it easy to deploy your Docker containers across a cluster of 
servers, making efficient use of wherever resources are available. Moreover, EKS can automatically scale your app up 
and down in response to load and redeploy containers that crashed.

For a quick intro to Docker, see [Running microservices on AWS using Docker, Terraform, and 
ECS](http://www.ybrikman.com/writing/2016/03/31/infrastructure-as-code-microservices-aws-docker-terraform-ecs/).
For more info on using EKS, see [terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks).




## Data stores

The infrastructure includes the following data stores:

1. **PostgreSQL**: PostgreSQL is deployed using [Amazon's Relational Database Service 
  (RDS)](https://aws.amazon.com/rds/), including automatic failover, backups, and replicas. Check out the 
  [rds service](https://github.com/gruntwork-io/aws-service-catalog/tree/master/modules/data-stores/rds) for more info.




## OpenVPN server

To reduce surface area to attackers, just about all of the resources in this infrastructure run in private subnets, 
which are not accessible from the public Internet at all. To allow company employees to access these private resources, 
we expose a single server publicly: an [OpenVPN server](https://openvpn.net/). Once you connect to the server using a 
VPN client, you are "in the network", and will be able to access the private resources (e.g., you will be able to SSH 
to your EC2 Instances).

For more info, see the [openvpn 
service](https://github.com/gruntwork-io/aws-service-catalog/tree/master/modules/mgmt/openvpn-server) and the VPN 
section of the [Authentication docs](02-authenticate.md).




## CircleCI

We have set up [CircleCi](https://circleci.com/) as a Continuous Integration (CI) server. After every commit, a CircleCi 
job runs your build, tests, packaging, and automated deployment steps.

For more info, see the [CI / CD docs](04-configure-ci-cd.md).




## Monitoring, log aggregation, alerting

You can find metrics, log files from all your servers, and subscribe to alert notifications using [Amazon 
CloudWatch](https://aws.amazon.com/cloudwatch/).

For more info, see the [Monitoring, Alerting, and Logging docs](05-monitoring-alerting-logging.md).




## DNS and TLS

We are using [Amazon Route 53](https://aws.amazon.com/route53/) to configure DNS entries for all services. We
have configured SSL/TLS certificates for your domain names using [Amazon's Certificate Manager 
(ACM)](https://aws.amazon.com/certificate-manager/), which issues certificates that are free and renew automatically.

For more info, see the [route53 service](https://github.com/gruntwork-io/aws-service-catalog/tree/master/modules/networking/route53).




## Security

We have configured security best practices in every aspect of this infrastructure:

* **Network security**: see [VPCs and subnets](#vpcs-and-subnets).

* **Server access**: see SSH and VPN sections of the [Authentication docs](02-authenticate.md).

* **Application secrets**: see secrets management section of the [Deploy your Apps docs](03-deploy-apps.md).

* **User accounts**: see the [Authentication docs](02-authenticate.md).

* **Auditing**: see the [CloudTrail](https://github.com/gruntwork-io/module-security/tree/master/modules/cloudtrail) and
  [AWS Config](https://github.com/gruntwork-io/module-security/tree/master/modules/aws-config) modules.

* **Intrusion detection**: see the [fail2ban](https://github.com/gruntwork-io/module-security/tree/master/modules/fail2ban)
  and [GuardDuty](https://github.com/gruntwork-io/module-security/tree/master/modules/guardduty-multi-region) modules.

* **Security updates**: see the [auto-update module](https://github.com/gruntwork-io/module-security/tree/master/modules/auto-update).

Check out [Gruntwork Security Best 
Practices](https://docs.google.com/document/d/e/2PACX-1vTikva7hXPd2h1SSglJWhlW8W6qhMlZUxl0qQ9rUJ0OX22CQNeM-91w4lStRk9u2zQIn6lPejUbe-dl/pub) 
for more info.





## Next steps

Next up, let's have a look at [how to authenticate](02-authenticate.md).



