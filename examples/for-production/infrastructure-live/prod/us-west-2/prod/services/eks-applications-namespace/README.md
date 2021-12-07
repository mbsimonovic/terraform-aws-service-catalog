# Kubernetes Namespace

This directory creates a [Kubernetes
Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) to host applications in.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.65.0/modules/services/k8s-namespace) for more
information about the underlying Terraform module.
