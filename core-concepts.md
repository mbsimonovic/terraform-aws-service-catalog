# Gruntwork Service Catalog Core Concepts

This documentation shows the core concepts of how to use the Gruntwork Service Catalog.

* [Gruntwork Service Catalog Overview](#gruntwork-service-catalog-overview)
* [How to deploy new infrastructure from the Service Catalog](#deploy-new-infrastructure)
* [How to update infrastructure from the Service Catalog](#make-changes-to-your-infrastructure)
* [How to create your own Service Catalog](#create-your-own-service-catalog)
* [Support](#support)
* [Contributing to this repo](#contributing-to-this-repo)



## Gruntwork Service Catalog Overview

The Gruntwork Service Catalog consists of a number of reusable, customizable, battle-tested, production-grade 
[infrastructure-as-code services](/modules) that you can use to deploy and manage your infrastructure, including Docker 
orchestration, EC2 orchestration, load balancing, networking, databases, caches, monitoring, alerting, CI/CD, secrets 
management, VPN, and much more. 

1. [Service Catalog Terminology](#service-catalog-terminology)
1. [The tools used in the Service Catalog](#the-tools-used-in-the-service-catalog)
1. [How to navigate the Service Catalog](#how-to-navigate-the-service-catalog)
1. [Maintenance and versioning](#maintenance-and-versioning)


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
  Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/) is a collection of battle-tested, commercially 
  supported and maintained services that you can use to deploy production-grade infrastructure in minutes.


### The tools used in the Service Catalog

The Gruntwork Service Catalog is designed to be deployed using the following tools:

1. [Terraform](https://www.terraform.io/). Used to define and manage most of the basic infrastructure, such as servers, 
   databases, load balancers, and networking. The Gruntwork Service Catalog is compatible with vanilla 
   [Terraform](https://www.terraform.io/), [Terragrunt](https://terragrunt.gruntwork.io/), [Terraform 
   Cloud](https://www.hashicorp.com/blog/announcing-terraform-cloud/), and [Terraform 
   Enterprise](https://www.terraform.io/docs/enterprise/index.html).

1. [Packer](https://www.packer.io/). Used to define and manage _machine images_ (e.g., VM images). The main use case is
   to package code as [Amazon Machine Images (AMIs)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) 
   that run on EC2 instances. Once you've built an AMI, you use Terraform to deploy it into AWS. 


### How to navigate the Service Catalog

The code in the `terraform-aws-service-catalog` repo is organized into three primary folders:

1. `modules`: The core implementation code of this repo. All the services that you will use and deploy are defined 
   within, such as the EKS cluster service in `modules/services/eks-cluster`.

1. `examples`: Sample code that shows how to use the services in the `modules` folder and allows you to try the 
   services out without having to write any code: you `cd` into one of the folders, follow a few steps in the README 
   (e.g., run `terraform apply`), and you'll have fully working infrastructure up and running. In other words, this is
   executable documentation. Note that the `examples` folder contains two sub-folders: 
   
    1. `for-learning-and-testing`: Example code that is optimized for learning, experimenting, and testing, but not 
       direct production usage). Most of these examples use Terraform directly to make it easy to fill in dependencies 
       that are convenient for testing, but not necessarily those you'd use in production: e.g., default VPCs or mock 
       database URLs.     

    1. `for-production`: Example code optimized for direct usage in production. This is code from the [Gruntwork Reference 
       Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an end-to-end, 
       integrated tech stack on top of the Gruntwork Service Catalog. To keep the code DRY and manage dependencies 
       between modules, the code is deployed using [Terragrunt](https://terragrunt.gruntwork.io/). However, Terragrunt
       is NOT required to use the Gruntwork Service Catalog: you can alternatively use vanilla Terraform or Terraform 
       Cloud / Enterprise, as described later in these docs.

1. `test`: Automated tests for the code in `modules` and `examples`.


### Maintenance and versioning

All of the code in the Gruntwork Service Catalog is _versioned_. The Service Catalog is commercially maintained by 
Gruntwork, and every time we make a change, we put out a new [versioned 
release](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases), and announce it in the monthly [Gruntwork 
Newsletter](https://blog.gruntwork.io/tagged/gruntwork-newsletter). 

We use version numbers of the form `MAJOR.MINOR.PATCH` (e.g., `1.2.3`), following the principles of [semantic 
versioning](https://semver.org/). In traditional semantic versioning, you increment the:

1. MAJOR version when you make incompatible API changes,
1. MINOR version when you add functionality in a backwards compatible manner, and
1. PATCH version when you make backwards compatible bug fixes.

However, much of the Gruntwork Service Catalog is built on Terraform, and as Terraform is still not at version 1.0.0, 
the code in the Service Catalog is is using `0.MINOR.PATCH` version numbers. With `0.MINOR.PATCH`, the rules are a bit 
different, where you increment the:

1. MINOR version when you make incompatible API changes
1. PATCH version when you add backwards compatible functionality or bug fixes.

We try to minimize backwards incompatible changes, but when we have to make one, we bump the MINOR version number, and
include migration instructions in the [release notes](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases).
Makes sure to ALWAYS read the release notes and migration instructions (if any) to avoid errors and outages! 




## Deploy new infrastructure

1. [How to deploy Terraform code from the Service Catalog](#how-to-deploy-terraform-code-from-the-service-catalog)
1. [How to build machine images using Packer templates from the Service Catalog](#how-to-build-machine-images-using-packer-templates-from-the-service-catalog)


### How to deploy Terraform code from the Service Catalog

There are three ways to use Terraform code from the Service Catalog:

1. [Using vanilla Terraform with the Service Catalog](#using-vanilla-terraform-with-the-service-catalog)
1. [Using Terragrunt with the Service Catalog](#using-terragrunt-with-the-service-catalog)
1. [Using Terraform Cloud or Terraform Enterprise with the Service Catalog](#using-terraform-cloud-or-terraform-enterprise-with-the-service-catalog)

#### Using vanilla Terraform with the Service Catalog

Below are the instructions for using the vanilla `terraform` binary—that is, with no wrappers, extensions, or UI—to 
deploy Terraform code from the Service Catalog. See 
[examples/for-learning-and-testing](/examples/for-learning-and-testing) for working sample code.

1. **Find a service**. Browse the `modules` folder to find a service you wish to deploy. For this tutorial, we'll use 
   the `vpc` service in [modules/networking/vpc](/modules/networking/vpc) as an example.
   
1. **Create a Terraform configuration**. Create a Terraform configuration file, such as `main.tf`.

1. **Configure the provider**. Inside of `main.tf`, configure the Terraform 
   [providers](https://www.terraform.io/docs/providers/index.html) for your chosen service. For `vpc`, and for
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
      # Make sure to replace <VERSION> in this URL with the latest terraform-aws-service-catalog release from
      # https://github.com/gruntwork-io/terraform-aws-service-catalog/releases
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=<VERSION>"
    
      # Fill in the arguments for this service
      aws_region       = "eu-west-1"
      vpc_name         = "example-vpc"
      cidr_block       = "10.0.0.0/16"
      num_nat_gateways = 1
      create_flow_logs = false
    }
    ```

    Let's walk through the code above:
    
    1. **Module**. We pull in the code for the service using Terraform's native `module` keyword. For background info, 
       see [How to create reusable infrastructure with Terraform 
       modules](https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d).

    1. **Git / SSH URL**. We recommend setting the `source` URL to a Git URL with SSH authentication (see [module 
       sources](https://www.terraform.io/docs/modules/sources.html) for other types of source URLs you can use). This
       will allow you to access the code in the Gruntwork Service Catalog using an SSH key for authentication, without
       having to hard-code credentials anywhere. 
       
    1. **Versioned URL**. Note the `?ref=<VERSION>` at the end of the `source` URL. This parameter allows you to pull 
       in a specific version of each service so that you don’t accidentally pull in potentially backwards incompatible 
       code in the future. You should replace `<VERSION>` with the latest version from the [releases 
       page](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases).       

    1. **Arguments**. Below the `source` URL, you’ll need to pass in the arguments specific to that service. You can 
       find all the required and optional variables defined in `variables.tf` of the service (e.g., check out 
       the [`variables.tf` for `vpc`](/modules/networking/vpc/variables.tf)).                          

1. **Add outputs**. You may wish to add some output variables, perhaps in an `outputs.tf` file, that forward along
   some of the output variables from the service. You can find all the outputs defined in `outputs.tf` for the service
   (e.g., check out [`outputs.tf` for `vpc`](/modules/networking/vpc/outputs.tf)). 
   
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

1. **Authenticate**. You will need to authenticate to both AWS and GitHub:

    1. **AWS Authentication**: See [A Comprehensive Guide to Authenticating to AWS on the Command 
       Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
       instructions.
   
    1. **GitHub Authentication**: All of Gruntwork's code lives in GitHub, and as most of the repos are private, you must 
       authenticate to GitHub to be able to access the code. For Terraform, we recommend using Git / SSH URLs and using
       SSH keys for authentication. See [How to get access to the Gruntwork Infrastructure as Code 
       Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#get_access)
       for instructions on setting up your SSH key.   

1. **Deploy**. You can now deploy the service as follows:
   
    ```bash
    terraform init
    terraform apply
    ```   

#### Using Terragrunt with the Service Catalog

[Terragrunt](https://terragrunt.gruntwork.io/) is a thin, open source wrapper for Terraform that helps you keep your
code [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself). Below are the instructions for using the `terragrunt` 
binary to deploy Terraform code from the Service Catalog. See [examples/for-production](/examples/for-production) for working 
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
       └ vpc/
         └ terragrunt.hcl   # child terragrunt.hcl
```

Here's how you configure the root `terragrunt.hcl`:

1. **Configure the provider**. Inside of `terragrunt.hcl`, configure the Terraform 
   [providers](https://www.terraform.io/docs/providers/index.html) for your chosen service. For `vpc`, and for
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
   the `vpc` service in [modules/networking/vpc](/modules/networking/vpc) as an example.
   
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
      # Make sure to replace <VERSION> in this URL with the latest terraform-aws-service-catalog release from
      # https://github.com/gruntwork-io/terraform-aws-service-catalog/releases
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=<VERSION>"
    }
 
    # Fill in the arguments for this service
    inputs = {
      aws_region       = "eu-west-1"
      vpc_name         = "example-vpc"
      cidr_block       = "10.0.0.0/16"
      num_nat_gateways = 1
      create_flow_logs = false
    }
    ```

    Let's walk through the code above:
    
    1. **Module**. We pull in the code for the service using Terragrunt's support for [remote Terraform 
       configurations](https://terragrunt.gruntwork.io/docs/features/keep-your-terraform-code-dry/).

    1. **Git / SSH URL**. We recommend setting the `source` URL to a Git URL with SSH authentication (see [module 
       sources](https://www.terraform.io/docs/modules/sources.html) for other types of source URLs you can use). This
       will allow you to access the code in the Gruntwork Service Catalog using an SSH key for authentication, without
       having to hard-code credentials anywhere.
       
    1. **Versioned URL**. Note the `?ref=<VERSION>` at the end of the `source` URL. This parameter allows you to pull 
       in a specific version of each service so that you don’t accidentally pull in potentially backwards incompatible 
       code in the future. You should replace `<VERSION>` with the latest version from the [releases 
       page](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases).       

    1. **Arguments**. In the `inputs` block, you’ll need to pass in the arguments specific to that service. You can 
       find all the required and optional variables defined in `variables.tf` of the service (e.g., check out 
       the [`variables.tf` for `vpc`](/modules/networking/vpc/variables.tf)).                          

1. **Authenticate**. You will need to authenticate to both AWS and GitHub:

    1. **AWS Authentication**: See [A Comprehensive Guide to Authenticating to AWS on the Command 
       Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
       instructions.
   
    1. **GitHub Authentication**: All of Gruntwork's code lives in GitHub, and as most of the repos are private, you must 
       authenticate to GitHub to be able to access the code. For Terraform, we recommend using Git / SSH URLs and using
       SSH keys for authentication. See [How to get access to the Gruntwork Infrastructure as Code 
       Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#get_access)
       for instructions on setting up your SSH key.   

1. **Deploy**. You can now deploy the service as follows:
   
    ```bash
    terragrunt apply
    ```   

#### Using Terraform Cloud or Terraform Enterprise with the Service Catalog

*(Documentation coming soon. If you need help with this ASAP, please contact [support@gruntwork.io](mailto:support@gruntwork.io).)*


### How to build machine images using Packer templates from the Service Catalog

Some of the services in the Gruntwork Service Catalog require you to build an [Amazon Machine Image 
(AMI)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) to install and configure the software that will
run on EC2 instances. These services define and manage the AMI as code using [Packer](https://www.packer.io/) templates.

For example, the [eks-cluster](/modules/services/eks-cluster) service defines an 
[eks-node-al2.json](/modules/services/eks-cluster/eks-node-al2.json) Packer template that can be used to create an AMI
for the Kubernetes worker nodes. This Packer template uses the [EKS optimized 
AMI](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html) as its base, which already has Docker, 
kubelet, and the AWS IAM Authenticator installed, and on top of that, it installs the other common software you'll
want on an EC2 instance in production, such as tools for gathering metrics, log aggregation, intrusion prevention,
and so on.

Below are instructions on how to build an AMI using these Packer templates. We'll be using the 
[eks-node-al2.json](/modules/services/eks-cluster/eks-node-al2.json) Packer template as an example.

1. **Check out the code**. Run `git clone git@github.com:gruntwork-io/terraform-aws-service-catalog.git` to check out the code
   onto your own computer.
   
1. **(Optional) Make changes to the Packer template**. If you need to install custom software into your AMI—e.g., extra
   tools for monitoring or other server hardening tools required by your company—copy the Packer template into one of
   your own Git repos, update it accordingly, and make sure to commit the changes. Note that the Packer templates in 
   the Gruntwork Service Catalog are designed to capture all the install steps in a single `shell` provisioner that 
   uses the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer) to install and configure the 
   software in just a few lines of code. We intentionally designed the templates this way so you can easily copy the
   Packer template, add all the custom logic you need for your use cases, and only have a few lines of versioned 
   Gruntwork code to maintain to pull in all the Service Catalog logic.

1. **Authenticate**. You will need to authenticate to both AWS and GitHub:

    1. **AWS Authentication**: See [A Comprehensive Guide to Authenticating to AWS on the Command 
       Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
       instructions.
   
    1. **GitHub Authentication**: All of Gruntwork's code lives in GitHub, and as most of the repos are private, you must 
       authenticate to GitHub to be able to access the code. For Packer, you must use a GitHub personal access
       token set as the environment variable `GITHUB_OAUTH_TOKEN` for authentication: 
       
        ```bash
        export GITHUB_OAUTH_TOKEN=xxx
        ```
       
        See [How to get access to the Gruntwork Infrastructure as Code 
        Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#get_access)
        for instructions on setting up GitHub personal access token.

1. **Set variables**. Each Packer template defines variables you can set in a `variables` block at the top, such as 
   what AWS region to use, what VPC to use for the build, what AWS accounts to share the AMI with, etc. We recommend
   setting these variables in a [JSON vars file](https://www.packer.io/docs/templates/user-variables/#from-a-file) and 
   checking that file into version control so that you have a versioned history of exactly what settings you used when 
   building each AMI. For example, here's what `eks-vars.json` might look like:
   
    ```json
    {
      "service_catalog_ref": "<VERSION>",
      "version_tag": "<TAG>"
    }
    ```
    
    This file defines two variables that are required by almost every Packer template in the Gruntwork Service Catalog:    
 
    1. **Service Catalog Version**. You must replace `<VERSION>` with the version of the Service Catalog (from the
       [releases page](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases)) you wish to use for this build.  
       Specifying a specific version allows you to know exactly what code you're using and ensures you don’t 
       accidentally pull in potentially backwards incompatible code in future builds.       
    
    1. **AMI Version**. You must replace `<TAG>` with the version number to use for this AMI. The Packer build will add
       a `version` tag to the AMI with this value, which provides a more human-friendly and readable version number
       than an AMI ID that you could use to find and sort your AMIs. You'll want to use a different `<TAG>` every time
       you run a Packer build. 

1. **Build**. Now you can build an AMI as follows:

    ```bash
    packer build -var-file=eks-vars.json eks-node-al2.json
    ```

1. **Deploy**. At the end of the build, Packer will output the ID of your new AMI. Typically, you deploy this AMI by
   plugging the AMI ID into some Terraform code and using Terraform to deploy it: e.g., plugging in the EKS worker node
   AMI ID into the `cluster_instance_ami` input variable of the [eks-cluster Terraform 
   module](/modules/services/eks-cluster).




## Make changes to your infrastructure

Now that your infrastructure is deployed, let's discuss how to make changes to it:

1. [Making changes to Terraform code](#making-changes-to-terraform-code)
1. [Making changes to Packer templates](#making-changes-to-packer-templates)


### Making changes to Terraform code

1. [Making changes to vanilla Terraform code](#making-changes-to-vanilla-terraform-code)
1. [Making changes to Terragrunt code](#making-changes-to-terragrunt-code)
1. [Making changes with Terraform Cloud or Terraform Enterprise](#making-changes-with-terraform-cloud-or-terraform-enterprise)

#### Making changes to vanilla Terraform code

1. **(Optional) Update your configuration**: One type of change you could do in your Terraform code (in the `.tf` 
   files) is to update the arguments you're passing to the service. For example, perhaps you update from one NAT 
   Gateway:
   
    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.1"
    
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 1
    }    
    ```     

    To 3 NAT Gateways for high availability:

    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.1"
    
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 3
    }    
    ```     

1. **(Optional) Update the Service Catalog version**: Another type of change you might make is to update the version
   of the Service Catalog you're using. For example, perhaps you update from version `v0.0.1`:
   
    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.1"
    
      # ... (other args ommitted for readability) ...
    }    
    ```     
   
   To version `v0.0.2`:
   
    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.2"
    
      # ... (other args ommitted for readability) ...
    }    
    ```     
   
    NOTE: Whenever changing version numbers, make sure to read the [release 
    notes](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases), especially if it's a backwards incompatible 
    release (e.g., `v0.0.1` -> `v0.1.0`), to avoid errors and outages (see [maintenance and 
    versioning](#maintenance-and-versioning) for details)!   

1. **Deploy**. Once you've made your changes, you can re-run `terraform apply` to deploy them:

    ```bash
    terraform apply
    ```
    
    Since Terraform [maintains state](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa), it will
    now update your infrastructure rather than deploying something new. As part of running `apply`, Terraform will show
    you the plan output, which will show you what's about to change before changing it. Make sure to scan the plan 
    output carefully to catch potential issues, such as something important being deleted that shouldn't be (e.g., a 
    database!). 

#### Making changes to Terragrunt code

1. **(Optional) Update your configuration**: One type of change you could do in your Terragrunt code (in the 
   `terragrunt.hcl` files) is to update the arguments you're passing to the service. For example, perhaps you update 
   from one NAT Gateway:
   
    ```hcl
    terraform {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.1"
    }
 
    inputs = {
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 1
    }    
    ```     

    To 3 NAT Gateways for high availability:

    ```hcl
    terraform {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.1"
    }
 
    inputs = {
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 3
    }   
    ```     

1. **(Optional) Update the Service Catalog version**: Another type of change you might make is to update the version
   of the Service Catalog you're using. For example, perhaps you update from version `v0.0.1`:
   
    ```hcl
    terraform {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.1"
    }
    ```     
   
   To version `v0.0.2`:
   
    ```hcl
    terraform {
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=v0.0.2"
    } 
    ```     
   
    NOTE: Whenever changing version numbers, make sure to read the [release 
    notes](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases), especially if it's a backwards incompatible 
    release (e.g., `v0.0.1` -> `v0.1.0`), to avoid errors and outages (see [maintenance and 
    versioning](#maintenance-and-versioning) for details)!   

1. **Deploy**. Once you've made your changes, you can re-run `terragrunt apply` to deploy them:

    ```bash
    terragrunt apply
    ```
    
    Since Terraform [maintains state](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa), it will
    now update your infrastructure rather than deploying something new. As part of running `apply`, Terraform will show
    you the plan output, which will show you what's about to change before changing it. Make sure to scan the plan 
    output carefully to catch potential issues, such as something important being deleted that shouldn't be (e.g., a 
    database!). 

#### Making changes with Terraform Cloud or Terraform Enterprise

*(Documentation coming soon. If you need help with this ASAP, please contact [support@gruntwork.io](mailto:support@gruntwork.io).)*


### Making changes to Packer templates

1. **(Optional) Update variables**: One type of change you might make is to update the variables you set in your vars
   file. In particular, you may wish to use a newer version of the Service Catalog for the build. For example, perhaps 
   you update from version `v0.0.1`:
   
    ```json
    {
      "service_catalog_ref": "v0.0.1"
    }
    ``` 
   
   To version `v0.0.2`:
   
    ```json
    {
      "service_catalog_ref": "v0.0.2"
    }
    ``` 
   
    NOTE: Whenever changing version numbers, make sure to read the [release 
    notes](https://github.com/gruntwork-io/terraform-aws-service-catalog/releases), especially if it's a backwards incompatible 
    release (e.g., `v0.0.1` -> `v0.1.0`), to avoid errors and outages (see [maintenance and 
    versioning](#maintenance-and-versioning) for details)!   

1. **(Optional) Update your custom Packer template**: If you made a copy of one of of the Packer templates, you can
   of course also make updates to your own template.

1. **Build**. Once you've made your changes, you can re-run `packer build` to build a new AMI:

    ```bash
    packer build -var-file=eks-vars.json eks-node-al2.json
    ```
    
1. **Deploy**. Once you've built a new AMI, you'll need to [make changes to your Terraform code and deploy 
   it](#making-changes-to-terraform-code). 




## Create your own service catalog

The services in the Gruntwork Service Catalog will fit ~80% of use cases right out of the box, but for the other 20%, 
you will need to customize things to fit your use cases. This section will walk you through how to handle those use 
cases by creating your own Service Catalog:

1. [Do it with the Gruntwork Service Catalog](#do-it-with-the-gruntwork-service-catalog)
1. [Creating a Service Catalog](#creating-a-service-catalog)
1. [Testing your Service Catalog](#testing-your-service-catalog)
1. [Deploying from your Service Catalog](#deploying-from-your-service-catalog)


### Do it with the Gruntwork Service Catalog 

Creating and maintaining your own Service Catalog is a lot of work, so the first thing to ask is: can you do it with
the Gruntwork Service Catalog? There are two things to check:

1. **Does the Service Catalog support it already?** The services in the Gruntwork Service Catalog are highly 
   customizable: what region to deploy to, what VPC and subnets to use, how to do secrets management, what to use for 
   metrics and logging, and many other settings are all configurable. Check the `variables.tf` file for Terraform 
   services and the `variables` block at the top of Packer templates to see if there is already a way to do what you 
   want.
   
1. **Should the Service Catalog be updated to support it?** If the Service Catalog doesn't already support the 
   functionality you need, the next question to ask is if it should. As a general rule, if your use case is fairly 
   common and likely affects many companies, we should support it! If that's the case, please [file a GitHub issue in 
   this repo](https://github.com/gruntwork-io/terraform-aws-service-catalog/issues/new), and the Gruntwork team may be able to implement it for you. Also, pull requests are VERY welcome! See 
   [Contributing to the Gruntwork Service 
   Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#_contributing_to_the_gruntwork_infrastructure_as_code_library)
   for instructions.      

If your use case isn't handled by the Gruntwork Service Catalog, and it's something fairly specific to your company, 
then you'll need to handle it in your own Service Catalog. Let's discuss how to do that.
 
 
### Creating a Service Catalog

A Service Catalog is really just a Git repo used in a certain way! Here's what you need to do:

1. **Create a Git repo**: Create a Git repo in your company. Let's say it's called `infrastructure-modules`.

1. **Set up the folder structure**. We recommend using the same [folder structure as the Gruntwork Service 
   Catalog](#how-to-navigate-the-service-catalog), with `modules`, `examples`, and `test` folders.

1. **Configure versioning**. We recommend versioning your code using Git tags. You can create Git tags at the command
   line as follows:
   
    ```bash
    git tag -a "v1.2.3" -m "Description of tag"
    git push --follow-tags
    ```
    
    Alternatively, some version control systems, such as GitHub, allow you to create "Releases" in the UI. Under the
    hood, the release tags are stored as Git tags. 

Now that you have a Service Catalog, you can start populating it with services. There are two ways to do that:

1. [Extend Gruntwork Services](#extend-gruntwork-services)
1. [Create totally new Services](#create-totally-new-services)

#### Extend Gruntwork Services

One way to populate your Service Catalog is to extend Gruntwork Services. There are several ways to do this:

1. **(RECOMMENDED) Wrap a Gruntwork Service**. The best way to extend a Gruntwork Service is to wrap it and add your
   additional functionality on top of it. Since Gruntwork Services export the IDs of all resources they create, adding
   new logic / functionality is easy. For example, let's say the `vpc` service creates a VPC more or less like
   you want it, but you need some additional routing logic that's specific to your company. What you can do is create
   a module in your Private Service Catalog (e.g., in `infrastructure-modules/modules/networking/vpc`) that wraps
   the Gruntwork `vpc` service as follows:
   
    ```hcl
    module "vpc" {
      # Make sure to replace <VERSION> in this URL with the latest terraform-aws-service-catalog release from
      # https://github.com/gruntwork-io/terraform-aws-service-catalog/releases
      source = "git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/vpc?ref=<VERSION>"
    
      # Fill in the arguments for this service
      aws_region       = "eu-west-1"
      vpc_name         = "example-vpc"
      cidr_block       = "10.0.0.0/16"
      num_nat_gateways = 1
      create_flow_logs = false
    }
    ```
    
    Now you can use outputs from the `vpc` service to add your custom routing behavior as follows:
    
    ```hcl
    resource "aws_route" "my_custom_route" {
      # Use an output from the vpc service to attach custom behavior!
      route_table_id         = module.vpc.public_subnet_route_table_id
      destination_cidr_block = "10.0.4.0/18"
      gateway_id             = var.my_custom_gateway_id
    }
    ```  

    You now have your own `vpc` service, with your custom routing logic, but most of the VPC code still lives in
    the Gruntwork Service Catalog and can be maintained by the Gruntwork team!

1. **(NOT RECOMMENDED) Copy a Gruntwork Service**. Another way to extend a Gruntwork Service is to copy all of the code
   for that one service into your own Git repo and modify the code directly. This is not recommended, as then you'll 
   have to maintain all of the code for that service yourself, and won't benefit from all the [maintenance 
   work](#maintenance-and-versioning) done by the Gruntwork team. The only reason to copy the code this way is if you 
   need a significant change that cannot be done from outside the service.
   
1. **(NOT RECOMMENDED) Fork the Gruntwork Service Catalog**. Yet another option is to 
   [fork](https://help.github.com/en/github/getting-started-with-github/fork-a-repo) the entire Gruntwork Service 
   Catalog into a repo of your own. This is not recommended, as then you'll have to maintain all of that code yourself, 
   and won't benefit from all the [maintenance work](#maintenance-and-versioning) done by the Gruntwork team. The only 
   reason to fork the entire repo is if you have a company policy that only allows you consume code from your own
   repositories. Note that if you do end up forking the entire Service Catalog, you can use `git fetch` and `git merge`
   to [automatically pull in changes from 
   upstream](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/syncing-a-forkhttps://help.github.com/en/github/collaborating-with-issues-and-pull-requests/syncing-a-fork) 
   (that is, from the original Gruntwork Service Catalog), but if you make any changes to your local fork, it'll be up
   to you to deal with merge conflicts. 
   

#### Create totally new Services

If you need something that is not supported at all in the Gruntwork Service Catalog, then you'll need to create your
own services from scratch. Here are a few resources to help you build your own reusable infrastructure code for 
production:

1. [Infrastructure Module Cookbook](https://training.gruntwork.io/p/infrastructure-module-cookbook). Our video training
   course on how to write reusable infrastructure code. You should have access to this course as part of your 
   Gruntwork Subscription (search your inbox for an invite from Teachable). If you're having trouble getting access,
   please email [support@gruntwork.io](mailto:support@gruntwork.io).
   
1. [5 Lessons Learned From Writing Over 300,000 Lines of Infrastructure Code](https://blog.gruntwork.io/5-lessons-learned-from-writing-over-300-000-lines-of-infrastructure-code-36ba7fadeac1).
   A talk and blog post that goes over some of the most important lessons for building reusable infrastructure code.

1. [Modules from the Gruntwork IaC Library](https://gruntwork.io/infrastructure-as-code-library/). We strongly 
   recommend building your own services by combining modules from the Gruntwork IaC Library. For example, if your 
   service runs in an Auto Scaling Group (ASG), you may want to use the modules from 
   [terraform-aws-asg](https://github.com/gruntwork-io/terraform-aws-asg) to create an ASG that can do zero-downtime rolling 
   deployments; if your service needs custom CloudWatch metrics, log aggregation, or alerts, you may want to use
   modules from [terraform-aws-monitoring](https://github.com/gruntwork-io/terraform-aws-monitoring); if your service is 
   doing something related to Kubernetes, you may want to use modules from 
   [terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks) or 
   [helm-kubernetes-services](https://github.com/gruntwork-io/helm-kubernetes-servicesv); and so on.
      
1. [The Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/). You can of course also use 
   the Gruntwork Service Catalog for inspiration and examples of how to build your own Service Catalog!


### Testing your Service Catalog

We strongly recommend writing automated tests for your Service Catalog. Here are some resources to help you along:

1. [Terratest](https://terratest.gruntwork.io/). This is the open source library we use to make it easier to write
   automated tests for all types of infrastructure code (Terraform, Packer, Docker, Kubernetes, etc).
   
1. [Automated Testing for Terraform, Docker, Packer, Kubernetes, and More](https://www.infoq.com/presentations/automated-testing-terraform-docker-packer/).
   A step-by-step, live-coding class on how to write automated tests for infrastructure code, including the code you 
   write for use with tools such as Terraform, Kubernetes, Docker, and Packer. Topics covered include unit tests, 
   integration tests, end-to-end tests, test parallelism, retries, error handling, static analysis, and more.

1. [The Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/). The Gruntwork Service Catalog
   has [thorough automated tests](/test), so you can use it for inspiration and examples of how to test your own 
   Service Catalog!   


### Deploying from your Service Catalog

Once you've created your own Service Catalog, developers at your company can deploy from it using the exact same 
techniques you use for [deploying from the Gruntwork Service Catalog](#deploy-new-infrastructure)! The only difference
is that instead of the URLs all pointing to Gruntwork's Git repos, you should update them to point to your Git repos.

For example, if you had your own `vpc` service in a repo called `infrastructure-modules` in the `acme` GitHub org, 
you could deploy that module using Terragrunt by writing a `terragrunt.hcl` file that looks something like this: 

```hcl
include {
  path = find_in_parent_folders()
}

terraform {
  # Note how the source URL is pointing to YOUR Service Catalog! Just make sure to replace <VERSION> in this URL with 
  # the latest release from your own Service Catalog. 
  source = "git@github.com:acme/infrastructure-modules.git//modules/networking/vpc?ref=<VERSION>"
}

# Fill in the arguments for this service
inputs = {
  aws_region       = "eu-west-1"
  vpc_name         = "example-vpc"
  cidr_block       = "10.0.0.0/16"
  num_nat_gateways = 1
}
```




## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers 
[Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. You can contact us using one of
the following channels:

* [Gruntwork Community Slack](https://gruntwork-community.slack.com): Chat with other Gruntwork customers and the 
  Gruntwork team.

* **Private Shared Slack Channel**: For Gruntwork Pro Support and Enterprise Support customers, we create a private, 
  shared channel in Slack between your company and Gruntwork that shows up in your existing Slack workspace. Contact
  one of your Slack admins to get the channel name!  

* [support@gruntwork.io](mailto:support@gruntwork.io): If you're having trouble contacting us via Slack, please feel 
  free to email Gruntwork Support at any time! 




## Contributing to this repo

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even
contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.

Please see: 

* [Contributing to the Gruntwork Service Catalog](core-concepts.md#contributing-to-the-gruntwork-service-catalog)
  for instructions.
* [Auto-update](#auto-update) for how dependencies are managed and updated in this repo.  
* [Pre-commit requirements](#pre-commit-requirements) for details on pre-commit hooks in this repo.


### Auto-update

This repo has been configured with support for automatic updates using 
[RenovateBot](https://renovate.whitesourcesoftware.com/), plus an experimental Gruntwork Registry endpoint. Here's how 
it works:

1. Any time a dependency of this repo releases an update, RenovateBot will automatically update the code in this repo 
   to use the new version and open up a PR with the changes.

1. To get the list of available versions, we are using an **experimental** Gruntwork Registry endpoint:

    1. The code for this endpoint lives in [the `gruntwork-registry` module in the Gruntwork prototypes 
       repo](https://github.com/gruntwork-io/prototypes/tree/master/gruntwork-registry).

    1. This endpoint is NOT ready for production use with all customers and could break at any time. If RenovateBot 
       works well for us with this repo, we'll work to productionize this endpoint and roll out RenovateBot to all 
       customers. 
    
    1. We are using a few weird hacks / workaronds. For example, all the `regex` managers in `renovate.json` set the
       `datasourceTemplate` to `terraform-module`, even for non Terraform code. This is largely because we haven't 
       figured out the right data source to use for all dependency types with our experimental endpoint, and pretending
       everything is a Terraform module works OK for now. Also, there are some TODOs in the code for dependencies we
       don't know how to update automatically, such as the Jenkins or Terraform version that gets installed (what 
       endpoint do we get that info from?).
       
    1. In the meantime, if you have questions or issues related to RenovateBot, contact [Jim](mailto:jim@gruntwork.io). 

1. RenovateBot is *extremely* configurable and customizable. The configuration is in [`renovate.json`](renovate.json).
   See the [RenovateBot documentation](https://docs.renovatebot.com/) for instructions.

1. Some auto-update conventions used in this repo:

    1. All Terraform and Terragrunt `source = <URL>?ref=XXX` dependencies get updated automatically.
    
    1. For certain file types, if you put `renovate.json auto-update: <REPO NAME>` above a variable declaration that
       specifies a version number, the version number will be automatically updated whenever `<REPO NAME>` has a new
       release. For example, in Bash scripts (`.sh` files):
       
        ```bash
        # renovate.json auto-update: terraform-aws-eks
        readonly DEFAULT_TERRAFORM_AWS_EKS_VERSION="v0.1.2"
        ```
        
        Any time there's a new release of the `terraform-aws-eks` repo, RenovateBot will submit a PR updating the
        version number in this Bash script. See [`renovate.json`](renovate.json) for other supported file types.
                

### pre-commit requirements 

This repo makes use of [pre-commit](https://pre-commit.com/) to help catch formatting and syntax issues client-side prior to code reviews. Gruntwork maintains [a collection of pre-commit hooks](https://github.com/gruntwork-io/pre-commit) that are specifically tailored to languages and tooling we commonly use.  

Before contributing to this repo: 

1. [Install pre-commit](https://pre-commit.com/#installation)
1. After cloning the repository, run `pre-commit install` in your local working directory 
1. You can examine the `.pre-commit-config.yml` file to see the hooks that will be installed and run when the git pre-commit hook is invoked. 
1. Python version >= 3.6 is required to run the hook scripts without issues. We recommend using [pyenv](https://github.com/pyenv/pyenvv) to manage multiple versions of Python on your system.
1. Once everything is working properly, you will notice that several checks are being run locally each time you run `git commit`. Note that your commit will not succeed until all `pre-commit` checks pass. 
1. However, you may bypass these safeguards and commit anyway by passing the `--no-verify` flag to your `git commit` command. This is usually not recommended. 
