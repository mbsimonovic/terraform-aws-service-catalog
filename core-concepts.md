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
  Service Catalog](https://github.com/gruntwork-io/aws-service-catalog/) is a collection of battle-tested, commercially 
  supported and maintained services that you can use to deploy production-grade infrastructure in minutes.


### The tools used in the Service Catalog

The Gruntwork Service Catalog is designed to be deployed using the following tools:

1. [Terraform](https://www.terraform.io/). Used to define and manage most of the basic infrastructure, such as servers, 
   databases, load balancers, and networking. The Gruntwork Service Catalog is compatible with pure, open source 
   [Terraform](https://www.terraform.io/), [Terragrunt](https://terragrunt.gruntwork.io/), [Terraform 
   Cloud](https://www.hashicorp.com/blog/announcing-terraform-cloud/), and [Terraform 
   Enteprise](https://www.terraform.io/docs/enterprise/index.html).

1. [Packer](https://www.packer.io/). Used to define and manage _machine images_ (e.g., VM images). The main use case is
   to package code as [Amazon Machine Images (AMIs)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) 
   that run on EC2 instances. Once you've built an AMI, you use Terraform to deploy it into AWS. 


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


### Maintenance and versioning

All of the code in the Gruntwork Service Catalog is _versioned_. The Service Catalog is commercially maintained by 
Gruntwork, and every time we make a change, we put out a new [versioned 
release](https://github.com/gruntwork-io/aws-service-catalog/releases), and announce it in the monthly [Gruntwork 
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
include migration instructions in the [release notes](https://github.com/gruntwork-io/aws-service-catalog/releases).
Makes sure to ALWAYS read the release notes and migration instructions (if any) to avoid errors and outages! 




## Deploy new infrastructure

1. [How to deploy Terraform code from the Service Catalog](#how-to-deploy-terraform-code-from-the-service-catalog)
1. [How to build machine images using Packer templates from the Service Catalog](#how-to-build-machine-images-using-packer-templates-from-the-service-catalog)


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

    1. **Git / SSH URL**. We recommend setting the `source` URL to a Git URL with SSH authentication (see [module 
       sources](https://www.terraform.io/docs/modules/sources.html) for other types of source URLs you can use). This
       will allow you to access the code in the Gruntwork Service Catalog using an SSH key for authentication, without
       having to hard-code credentials anywhere. 
       
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

1. **Authenticate**. You will need to authenticate to both AWS and GitHub:

    1. **AWS Authentication**: See [A Comprehensive Guide to Authenticating to AWS on the Command 
       Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
       instructions.
   
    1. **GitHub Authentication**: All of Gruntwork code lives in GitHub, and as most of the repos are private, you must 
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

    1. **Git / SSH URL**. We recommend setting the `source` URL to a Git URL with SSH authentication (see [module 
       sources](https://www.terraform.io/docs/modules/sources.html) for other types of source URLs you can use). This
       will allow you to access the code in the Gruntwork Service Catalog using an SSH key for authentication, without
       having to hard-code credentials anywhere.
       
    1. **Versioned URL**. Note the `?ref=<VERSION>` at the end of the `source` URL. This parameter allows you to pull 
       in a specific version of each service so that you don’t accidentally pull in potentially backwards incompatible 
       code in the future. You should replace `<VERSION>` with the latest version from the [releases 
       page](https://github.com/gruntwork-io/aws-service-catalog/releases).       

    1. **Arguments**. In the `inputs` block, you’ll need to pass in the arguments specific to that service. You can 
       find all the required and optional variables defined in `variables.tf` of the service (e.g., check out 
       the [`variables.tf` for `vpc-app`](/modules/networking/vpc-app/variables.tf)).                          

1. **Authenticate**. You will need to authenticate to both AWS and GitHub:

    1. **AWS Authentication**: See [A Comprehensive Guide to Authenticating to AWS on the Command 
       Line](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
       instructions.
   
    1. **GitHub Authentication**: All of Gruntwork code lives in GitHub, and as most of the repos are private, you must 
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

1. **Check out the code**. Run `git clone git@github.com:gruntwork-io/aws-service-catalog.git` to check out the code
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
   
    1. **GitHub Authentication**: All of Gruntwork code lives in GitHub, and as most of the repos are private, you must 
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
       [releases page](https://github.com/gruntwork-io/aws-service-catalog/releases)) you wish to use for this build.  
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

1. [Making changes to pure, vanilla Terraform code](#making-changes-to-pure-vanilla-terraform-code)
1. [Making changes to Terragrunt code](#making-changes-to-terragrunt-code)
1. [Making changes with Terraform Cloud or Terraform Enterprise](#making-changes-with-terraform-cloud-or-terraform-enterprise)

#### Making changes to pure, vanilla Terraform code

1. **(Optional) Update your configuration**: One type of change you could do in your Terraform code (in the `.tf` 
   files) is to update the arguments you're passing to the service. For example, perhaps you update from one NAT 
   Gateway:
   
    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
    
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 1
    }    
    ```     

    To 3 NAT Gateways for high availability:

    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
    
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 3
    }    
    ```     

1. **(Optional) Update the Service Catalog version**: Another type of change you might make is to update the version
   of the Service Catalog you're using. For example, perhaps you update from version `v0.0.1`:
   
    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
    
      # ... (other args ommitted for readability) ...
    }    
    ```     
   
   To version `v0.0.2`:
   
    ```hcl
    module "vpc" {
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.2"
    
      # ... (other args ommitted for readability) ...
    }    
    ```     
   
    NOTE: Whenever changing version numbers, make sure to read the [release 
    notes](https://github.com/gruntwork-io/aws-service-catalog/releases), especially if it's a backwards incompatible 
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
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
    }
 
    inputs = {
      # ... (other args ommitted for readability) ...
      num_nat_gateways = 1
    }    
    ```     

    To 3 NAT Gateways for high availability:

    ```hcl
    terraform {
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
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
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
    }
    ```     
   
   To version `v0.0.2`:
   
    ```hcl
    terraform {
      source = "git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.2"
    } 
    ```     
   
    NOTE: Whenever changing version numbers, make sure to read the [release 
    notes](https://github.com/gruntwork-io/aws-service-catalog/releases), especially if it's a backwards incompatible 
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
    notes](https://github.com/gruntwork-io/aws-service-catalog/releases), especially if it's a backwards incompatible 
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

Outline:

- Why you need one
  - Consumed same way as Gruntwork catalog, but from your URLs
- Configureable options in variables.tf and CLI args
- Contributing to the Gruntwork Service Catalog
- Extending a module with your own
- Forking the code
