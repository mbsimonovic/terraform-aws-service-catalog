# Gruntwork Sample App frontend EKS Service

This directory creates a [Kubernetes Service](https://github.com/gruntwork-io/helm-kubernetes-services/)
that runs the [Gruntwork AWS Sample App](https://github.com/gruntwork-io/aws-sample-app/) in
frontend mode.

Refer to the [Gruntwork AWS Sample App
documentation](https://github.com/gruntwork-io/aws-sample-app/blob/master/README.adoc) for more information about the
Gruntwork sample app.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.82.0/modules/services/k8s-service) for more
information about the underlying Terraform module that manages the ECS service.
