# DataDog ECS Task Module

This Terraform Module creates an ECS Task to run a [DataDog](https://www.datadoghq.com) agent. You
can run this Task on each EC2 Instance in your ECS Cluster to gather metrics about your Docker containers. See
[Datadog-AWS ECS Integration](https://docs.datadoghq.com/integrations/ecs) for more info.






## How do you use this module?

The basic idea is to:

1. Use this module to create a single copy of the DataDog ECS Task in your AWS account. See the [root
   README](/README.md) for instructions on using Terraform modules and [variables.tf](./variables.tf) for all the variables you
   can set on this module.

1. In the User Data script of your ECS Cluster, start this ECS Task as documented here:
   https://docs.datadoghq.com/integrations/ecs/#create-a-new-instance-including-a-startup-script. Note: you will need
   to pass your DataDog API Key as the environment variable `API_KEY` when starting the ECS Task. We do not include it
   in the container definition in this module to avoid storing the API Key in plain text in your Terraform code and
   remote state.
