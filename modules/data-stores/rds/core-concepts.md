## How do I use Kubernetes Service Discovery with the RDS Database?

This module supports creating Kubernetes [Service
resources](https://kubernetes.io/docs/concepts/services-networking/service/) for service discovery within the Kubernetes
cluster. When the input variable `create_kubernetes_service` is set to `true`, this module will create a Kubernetes
Service of type [ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname) that can
be used to route requests against that Service to the primary endpoint of the RDS database. The Service will have the
same name as the cluster (the `var.name` input variable) and be created in the Namespace specified by
`kubernetes_namespace`. With the Service, your Pods in Kubernetes can access the database under a more predictable name
without having to inject the FQDN of the RDS database.

For example, if you named your RDS database `main-rds-cluster` and you set the Namespace to `data-stores`, you can
access the database from your pods using the endpoint `main-rds-cluster.data-stores.svc.cluster.local`. Refer to
[the official Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) on
Service DNS for more information.
