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
1. [The tools used in the Service Catalog](#the-tools-used-in-the-service-catalog)
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
  are designed for specific use cases and meant to be deployed directly. For example, the `eks-cluster` service 
  combines all the modules you need to run an EKS (Kubernetes) cluster in a typical production environment, including 
  modules for the control plane, worker nodes, secrets management, log aggregation, alerting, and so on. The [Gruntwork 
  Service Catalog](https://github.com/gruntwork-io/aws-service-catalog/) is a collection of battle-tested, commercially 
  supported and maintained services that you can use to deploy production-grade infrastructure in minutes.


### The tools used in the Service Catalog

The Gruntwork Service Catalog is built to be used with the following tools:

1. [Terraform](https://www.terraform.io/). Used to define and manage most of the basic infrastructure, such as servers, 
   databases, load balancers, and networking. The Gruntwork Service Catalog is compatible with pure, open source 
   [Terraform](https://www.terraform.io/), [Terragrunt](https://terragrunt.gruntwork.io/), [Terraform 
   Cloud](https://www.hashicorp.com/blog/announcing-terraform-cloud/), and [Terraform 
   Enteprise](https://www.terraform.io/docs/enterprise/index.html).

1. [Packer](https://www.packer.io/). Used to define and manage _machine images_ (e.g., VM images). The main use case is
   to package code as [Amazon Machine Images (AMIs)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) 
   that run on EC2 instances. 

1. [Docker](https://www.docker.com/). Used to define and manage _containers_. A container is a bit like a lightweight 
   VM, except instead of virtualizing all the hardware and the entire operating system, containers virtualize solely 
   user space, which gives you many of the isolation benefits of a VM (each container is isolated in terms of memory, 
   CPU, networking, hard drive, etc), but with much less memory, CPU, and start-up time overhead. The main use case is
   to package code as Docker images that can be run with Docker orchestration tools such as Kubernetes, ECS, Fargate,
   etc.

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

1. [How to deploy Terraform code from the Service Catalog](#how-to-deploy-terraform-code-from-the-service-catalog)
1. [How to build machine images using Packer templates from the Service Catalog](#how-to-build-machine-images-using-packer-templates-from-the-service-catalog)
1. [How to build Docker images from the Service Catalog](#how-to-build-docker-images-from-the-service-catalog)
1. [How to use Helm charts from the Service Catalog](#how-to-use-helm-charts-from-the-service-catalog)


### How to deploy Terraform code from the Service Catalog

There are three ways to use Terraform code from the Service Catalog:

1. [Using pure, open source Terraform with the Service Catalog](#using-pure-open-source-terraform-with-the-service-catalog)
1. [Using Terragrunt with the Service Catalog](#using-terragrunt-with-the-service-catalog)
1. [Using Terraform Cloud or Terraform Enterprise with the Service Catalog](#using-terraform-cloud-or-terraform-enterprise-with-the-service-catalog)

#### Using pure, open source Terraform with the Service Catalog

Below are the instructions for using the vanilla, open source `terraform` binary to deploy Terraform code from the 
Service Catalog. See [examples/for-learning-and-testing](/examples/for-learning-and-testing) for working sample code.

1. **Find a service**. Browse the `modules` folder to find a service you wish to deploy. For this tutorial, we'll use 
   the `vpc-app` service in [modules/networking/vpc-app](/modules/networking/vpc-app) as an example.
   
1. **Create a Terraform configuration**. Create a Terraform configuration file, such as `main.tf`.

1. **Configure the provider**. Inside of `main.tf`, configure the Terraform 
   [providers](https://www.terraform.io/docs/providers/index.html) for your chosen service. For `vpc-app`, and for
   most of the services in this Service Catalog, you'll need to configure the [AWS 
   provider](https://www.terraform.io/docs/providers/aws/index.html):
   
    ```hcl
    provider "aws" {
      # The AWS region in which all resources will be created
      region = "eu-west-1"
    
      # Only these AWS Account IDs may be operated on by this template
      allowed_account_ids = ["111122223333"]
    }
    ```       

1. **Configure the backend**. You'll also want to configure the 
   [backend](https://www.terraform.io/docs/backends/index.html) to use to store Terraform state:

    ```hcl
    terraform {
      # Configure S3 as a backend for storing Terraform state
      backend "s3" {
        bucket         = "<YOUR S3 BUCKET>"
        region         = "eu-west-1"
        key            = "<YOUR PATH>/terraform.tfstate"
        encrypt        = true
        dynamodb_table = "<YOUR DYNAMODB TABLE>"
      }
    }
    ```

1. **Use the service**. Now you can add the service to your code:

    ```hcl
    module "vpc" {
      # Make sure to replace <VERSION> in this URL with the latest aws-service-catalog release from
      # https://github.com/gruntwork-io/aws-service-catalog/releases
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=<VERSION>"
    
      # Fill in the arguments for this service
      aws_region       = "eu-west-1"
      vpc_name         = "example-vpc"
      cidr_block       = "10.0.0.0/16"
      num_nat_gateways = 1
    }
    ```

    Let's walk through the code above:
    
    1. **Module**. We pull in the code for the service using Terraform's native `module` keyword. For background info, 
       see [How to create reusable infrastructure with Terraform 
       modules](https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d).

    1. **Git / SSH URL**. The `source` URL in the code above uses a Git URL with SSH authentication (see [module 
       sources](https://www.terraform.io/docs/modules/sources.html) for other types of source URLs you can use). This
       will allow you to access the code in the Gruntwork Service Catalog using an SSH key for authentication, without
       having to hard-code credentials anywhere. See [How to get access to the Gruntwork Infrastructure as Code 
       Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#get_access)
       for instructions on setting up your SSH key.
       
    1. **Versioned URL**. Note the `?ref=<VERSION>` at the end of the `source` URL. This parameter allows you to pull 
       in a specific version of each service so that you don’t accidentally pull in potentially backwards incompatible 
       code in the future. You should replace `<VERSION>` with the latest version from the [releases 
       page](https://github.com/gruntwork-io/aws-service-catalog/releases).       

    1. **Arguments**. Below the `source` URL, you’ll need to pass in the arguments specific to that service. You can 
       find all the required and optional variables defined in `variables.tf` of the service (e.g., check out 
       the [`variables.tf` for `vpc-app`](/modules/networking/vpc-app/variables.tf)).                          

1. **Add outputs**. You may wish to add some output variables, perhaps in an `outputs.tf` file, that forward along
   some of the output variables from the service. You can find all the outputs defined in `outputs.tf` for the service
   (e.g., check out [`outputs.tf` for `vpc-app`](/modules/networking/vpc-app/outputs.tf)). 
   
    ```hcl
    output "vpc_name" {
      description = "The VPC name"
      value       = module.vpc.vpc_name
    }
    
    output "vpc_id" {
      description = "The VPC ID"
      value       = module.vpc.vpc_id
    }
    
    output "vpc_cidr_block" {
      description = "The VPC CIDR block"
      value       = module.vpc.vpc_cidr_block
    }
    
    # ... Etc (see the service's outputs.tf for all available outputs) ...
    ```

1. **Deploy**. You're now ready to deploy the service! First, you'll need to authenticate to the relevant providers
   (for AWS authentication, see [A Comprehensive Guide to Authenticating to AWS on the Command 
   Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
   instructions), and then run:
   
    ```bash
    terraform init
    terraform apply
    ```   

#### Using Terragrunt with the Service Catalog

[Terragrunt](https://terragrunt.gruntwork.io/) is a thin, open source wrapper for Terraform that helps you keep your
code [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself). Below are the instructions for using the Terragrunt 
to deploy Terraform code from the Service Catalog. See [examples/for-production](/examples/for-production) for working 
sample code.

First, we need to do some one time setup. One of the ways Terragrunt helps you keep your code DRY is by allowing you to
define common configurations once in a root `terragrunt.hcl` file and to `include` those configurations in all child
`terragrunt.hcl` files. The folder structure might look something like this:

```
terragrunt.hcl              # root terragrunt.hcl
dev/
stage/
prod/
 └ eu-west-1/
    └ prod/
       └ vpc-app/
         └ terragrunt.hcl   # child terragrunt.hcl
```

Here's how you configure the root `terragrunt.hcl`:

1. **Configure the provider**. Inside of `terragrunt.hcl`, configure the Terraform 
   [providers](https://www.terraform.io/docs/providers/index.html) for your chosen service. For `vpc-app`, and for
   most of the services in this Service Catalog, you'll need to configure the [AWS 
   provider](https://www.terraform.io/docs/providers/aws/index.html). We'll do this using a 
   [`generate`](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#generate) block: 
   
    ```hcl
    generate "provider" {
      path      = "provider.tf"
      if_exists = "overwrite_terragrunt"
      contents  = <<EOF
    provider "aws" {
      # The AWS region in which all resources will be created
      region = "eu-west-1"
    
      # Only these AWS Account IDs may be operated on by this template
      allowed_account_ids = ["111122223333"]
    }
    EOF
    }
    ```   

1. **Configure the backend**. You'll also want to configure the 
   [backend](https://www.terraform.io/docs/backends/index.html) to use to store Terraform state. We'll do this using
   a [`remote_state`](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#remote_state) block: 

    ```hcl
    remote_state {
      backend = "s3"
      config = {
        bucket         = "<YOUR S3 BUCKET>"
        region         = "eu-west-1"
        key            = "${path_relative_to_include()}/terraform.tfstate"
        encrypt        = true
        dynamodb_table = "<YOUR DYNAMODB TABLE>"
      }
      generate = {
        path      = "backend.tf"
        if_exists = "overwrite_terragrunt"
      }
    }    
    ```

Now you can create child `terragrunt.hcl` files to deploy services as follows:

1. **Find a service**. Browse the `modules` folder to find a service you wish to deploy. For this tutorial, we'll use 
   the `vpc-app` service in [modules/networking/vpc-app](/modules/networking/vpc-app) as an example.
   
1. **Create a child Terragrunt configuration**. Create a child Terragrunt configuration file called `terragrunt.hcl`.

1. **Include the root Terragrunt configuration**. Pull in all the settings from the root `terragrunt.hcl` by using an
   [`include`](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#include) block:

    ```hcl
    include {
      path = find_in_parent_folders()
    }
    ```

1. **Use the service**. Now you can add the service to your child `terragrunt.hcl`:

    ```hcl
    terraform {
      # Make sure to replace <VERSION> in this URL with the latest aws-service-catalog release from
      # https://github.com/gruntwork-io/aws-service-catalog/releases
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=<VERSION>"
    }
 
    # Fill in the arguments for this service
    inputs = {
      aws_region       = "eu-west-1"
      vpc_name         = "example-vpc"
      cidr_block       = "10.0.0.0/16"
      num_nat_gateways = 1
    }
    ```

    Let's walk through the code above:
    
    1. **Module**. We pull in the code for the service using Terragrunt's support for [remote Terraform 
       configurations](https://terragrunt.gruntwork.io/docs/features/keep-your-terraform-code-dry/).

    1. **Git / SSH URL**. The `source` URL in the code above uses a Git URL with SSH authentication (see [module 
       sources](https://www.terraform.io/docs/modules/sources.html) for other types of source URLs you can use). This
       will allow you to access the code in the Gruntwork Service Catalog using an SSH key for authentication, without
       having to hard-code credentials anywhere. See [How to get access to the Gruntwork Infrastructure as Code 
       Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#get_access)
       for instructions on setting up your SSH key.
       
    1. **Versioned URL**. Note the `?ref=<VERSION>` at the end of the `source` URL. This parameter allows you to pull 
       in a specific version of each service so that you don’t accidentally pull in potentially backwards incompatible 
       code in the future. You should replace `<VERSION>` with the latest version from the [releases 
       page](https://github.com/gruntwork-io/aws-service-catalog/releases).       

    1. **Arguments**. In the `inputs` block, you’ll need to pass in the arguments specific to that service. You can 
       find all the required and optional variables defined in `variables.tf` of the service (e.g., check out 
       the [`variables.tf` for `vpc-app`](/modules/networking/vpc-app/variables.tf)).                          

1. **Deploy**. You're now ready to deploy the service! First, you'll need to authenticate to the relevant providers
   (for AWS authentication, see [A Comprehensive Guide to Authenticating to AWS on the Command 
   Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
   instructions), and then run:
   
    ```bash
    terragrunt apply
    ```   

#### Using Terraform Cloud or Terraform Enterprise with the Service Catalog

TODO


### How to build machine images using Packer templates from the Service Catalog

TODO


### How to build Docker images from the Service Catalog

TODO


### How to use Helm charts from the Service Catalog

TODO




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
