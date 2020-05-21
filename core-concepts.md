# Gruntwork Service Catalog Core Concepts

This documentation shows the core concepts of how to use the Gruntwork Service Catalog.

* [Gruntwork Service Catalog Overview](#gruntwork-service-catalog-overview)
* [How to deploy new infrastructure from the Service Catalog](#deploy-new-infrastructure)
* [How to update infrastructure from the Service Catalog](#make-changes-to-your-infrastructure)
* [How to create your own Service Catalog](#create-your-own-service-catalog)




## Gruntwork Service Catalog Overview

The Gruntwork Service Catalog consists of a number of reusable, customizable, battle-tested, production-grade 
[infrastructure-as-code services](/modules) that you can use to deploy and manage your infrastructure, including Docker 
orchestration, EC2 orchestration, load balancing, networking, databases, caches, monitoring, alerting, CI/CD, secrets 
management, VPN, and much more. 

1. [Service Catalog Terminology](#service-catalog-terminology)
1. [The tools and languages used in the Service Catalog](#the-tools-and-languages-used-in-the-service-catalog)
1. [How to navigate the Service Catalog](#how-to-navigate-the-service-catalog)


### Service Catalog Terminology

* **Module**: Reusable code to deploy and manage one piece of infrastructure. Modules are fairly generic building 
  blocks, so you don't typically deploy a single module directly, but rather, you write code that combines the modules 
  you need for a specific use case. For example, one module might deploy the control plane for Kubernetes and a 
  separate module could deploy worker nodes; you may need to combine both modules together to deploy a Kubernetes 
  cluster. The [Gruntwork Infrastructure as Code (IaC) Library](https://gruntwork.io/infrastructure-as-code-library/) 
  contains hundreds of battle-tested, commercially supported and maintained modules that you can use and combine in 
  many different ways.

* **Service**: Reusable code that combines multiple modules to configure a service for a specific use case. Services 
  are designed for specify use cases and meant to be deployed directly, without having to write more code. For 
  example, the `eks-cluster` service combines all the modules you need to run an EKS (Kubernetes) cluster in a typical 
  production environment, including modules for the control plane, worker nodes, secrets management, log aggregation, 
  alerting, and so on. The [Gruntwork Service Catalog](https://github.com/gruntwork-io/aws-service-catalog/) is a 
  collection of battle-tested, commercially supported and maintained services that you can use to deploy 
  production-grade infrastructure in minutes.


### The tools and languages used in the Service Catalog

The Gruntwork Service Catalog is built on top of the following tools and technologies:

1. [Terraform](https://www.terraform.io/). Used to define and manage most of the basic infrastructure, such as servers, 
   databases, load balancers, and networking.

1. [Go](https://golang.org/). Used to build cross-platform CLI applications (e.g., `ssh-grunt` is a Go app you can run 
   on your EC2 instances to manage SSH access to those instances via IAM groups) and to write automated tests (using 
   the open source Go library [Terratest](https://terratest.gruntwork.io/)).

1. [Bash](https://www.gnu.org/software/bash/). Used for small scripts on Linux and macOS, including:

    * _Install scripts_: Used to install and configure a piece of software. Example: the `install-elasticsearch` script 
      can be used to install Elasticsearch on Linux.

    * _Run scripts_: Used to run a piece of software, typically during boot. Example: you can execute the 
      `run-elasticsearch` script while a server is booting to auto-discover other Elasticsearch nodes and bootstrap an
      Elasticsearch cluster.

1. [Python](https://www.python.org/). Used for more complicated scripts, especially those that need to run on other 
   operating systems (e.g., Windows) and/or those that need to be called directly from Terraform (e.g., to fill in some 
   missing functionality).

1. [Packer](https://www.packer.io/). Used to define and manage _machine images_ (e.g., VM images such as AMIs). 

1. [Docker](https://www.docker.com/). Used to define and manage _containers_. A container is a bit like a lightweight 
   VM, except instead of virtualizing all the hardware and the entire operating system, containers virtualize solely 
   user space, which gives you many of the isolation benefits of a VM (each container is isolated in terms of memory, 
   CPU, networking, hard drive, etc), but with much less memory, CPU, and start-up time overhead.

1. [Helm](https://helm.sh/). Used to define and manage Kubernetes applications and resources. Example: `k8s-service` 
   is a helm chart that packages your application containers into a best practices deployment for Kubernetes.


### How to navigate the Service Catalog

The code in the `aws-service-catalog` repo is organized into three primary folders:

1. `modules`: The core implementation code of this repo. All the services that you will use and deploy are defined 
   within, such as the EKS cluster service in `modules/services/eks-cluster`.

1. `examples`: Sample code that shows how to use the services in the `modules` folder and allows you to try the 
   services out without having to write any code—in other words, executable documentation. Note that the `examples` 
   folder contains two sub-folders: 
   
    1. `for-learning-and-testing`: Example code that is optimized for learning, experimenting, and testing, but not 
       direct production usage). Most of these examples use Terraform directly to make it easy to fill in dependencies 
       that are convenient for testing, but not necessarily those you'd use in production: e.g., default VPCs or mock 
       database URLs.     

    1. `for-production`: Example code optimized for direct usage in production. This is code from the [Gruntwork Reference 
       Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an end-to-end, 
       integrated tech stack on top of the Gruntwork Service Catalog. To keep the code DRY and manage dependencies 
       between modules, the code is deployed using [Terragrunt](https://terragrunt.gruntwork.io/). However, Terragrunt
       is NOT required to use the Gruntwork Service Catalog: you can alternatively use pure Terraform or Terraform 
       Cloud / Enterprise, as described later in these docs.

1. `test`: Automated tests for the code in `modules` and `examples`.




## Deploy new infrastructure

Outline:

- Terraform
  - Pure Terraform
  - Terragrunt
  - Terraform Cloud / Enterprise
- Packer
- Docker
- Helm




## Make changes to your infrastructure

Outline:

- Versioning
  - Semantic versioning
  - Release notes
- Terraform
- Packer
- Docker
- Helm



## Create your own service catalog

Outline:

- Why you need one
  - Consumed same way as Gruntwork catalog, but from your URLs
- Configureable options in variables.tf and CLI args
- Contributing to the Gruntwork Service Catalog
- Extending a module with your own
- Forking the code
