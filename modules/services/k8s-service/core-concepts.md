## How do I expose my application to clients and other applications?

In general, `Pods` are considered ephemeral in Kubernetes. `Pods` can come and go at any point in time, either because
containers fail or the underlying instances crash. In either case, the dynamic nature of `Pods` make it difficult to
consistently access your application if you are individually addressing the `Pods` directly.

Traditionally, this is solved using service discovery, where you have a stateful system that the `Pods` would register
to when they are available. Then, your other applications can query the system to find all the available `Pods` and
access one of the available ones.

Kubernetes provides a built in mechanism for service discovery in the `Service` resource. `Services` are an abstraction
that groups a set of `Pods` behind a consistent, stable endpoint to address them. By creating a `Service` resource, you
can provide a single endpoint to other applications to connect to the `Pods` behind the `Service`, and not worry about
the dynamic nature of the `Pods`.

You can read a more detailed description of `Services` in [the official
documentation](https://kubernetes.io/docs/concepts/services-networking/service/).

In addition to `Service`, Kubernetes provides `Ingress` resources, which is a mechanism in Kubernetes that abstracts
externally exposing a `Service` from the `Service` config itself. `Ingress` resources support:

- assigning an externally accessible URL to a `Service`
- perform hostname and path based routing of `Services`
- load balance traffic using customizable balancing rules
- terminate SSL

You can read more about `Ingress` resources in [the official
documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/).

At a high level, the `Ingress` resource is used to specify the configuration for a particular `Service`. In turn, the
`Ingress Controller` is responsible for fulfilling those configurations in the cluster. This means that the first
decision to make in using `Ingress` resources, is selecting an appropriate `Ingress Controller` for your cluster. This
module assumes that you are using the AWS ALB Ingress controller.

This module supports exposing your application in three difference configurations, managed by the `expose_type` input
variable:

- `cluster-internal`: The application is only accessible within the Kubernetes cluster. Under the hood this creates a
  `ClusterIP` `Service` to expose an endpoint for the `Pods`.
- `internal`: The application is exposed external to the cluster, but internal to the VPC. Under the hood this is
  implemented using a `NodePort` `Service` that is hooked up to an `Ingress` resource that configures an AWS ALB that is
  internal to the VPC.
- `external`: The application is exposed publicly using the same set up as `internal`, but with an external facing AWS
  ALB.

For `internal` and `external` modes, you can additionally bind a hostname to the endpoint that is automatically
translated to a Route53 record if you have the [external-dns](https://github.com/kubernetes-sigs/external-dns)
application deployed. This is configured through the `create_route53_entry` and `domain_name` variables.

Note that you will need to query the `Ingress` resource to find the assigned endpoint if you are not associating a
domain with it. You can see the ALB domain when you run the following `kubectl` command:

```
kubectl get ingress --namespace $NAMESPACE -l "app.kubernetes.io/name=$APPLICATION_NAME,app.kubernetes.io/instance=$APPLICATION_NAME"
```

where `NAMESPACE` corresponds to what you passed into `var.namespace` and `APPLICATION_NAME` corresponds to what you
passed into `var.applciation_name`.

To access the `Service` within the Kubernetes cluster for any of the modes, you can use the DNS record
`$APPLICATION_NAME-$APPLICATION_NAME.$NAMESPACE.svc.cluster.local`.


## Configration and Secrets Management

Kubernetes provides a built in mechanism for configuration and secrets management of applications in the form of
`ConfigMap` and `Secrets` resources. Both resources behave similarly in that they both provide a key-value store that
can be injected into applications at run time either as environment variables, or as files on the container filesystem.
`Secrets` have additional protections that are optimized for storing secrets:

- `Secrets` are never written to disk and only available in memory.
- Unlike with `ConfigMaps`, `Secrets` are only shared to the nodes if a `Pod` that uses it is scheduled on the node.
- In certain Kubernetes clusters like EKS, `Secrets` are encrypted at rest.

You can read more about `ConfigMaps` and `Secrets` in the official documentation (see
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/[here] for `ConfigMaps` and
https://kubernetes.io/docs/concepts/configuration/secret/[here] for `Secrets`). You can also see our analysis of the
difference configuration options for your pods in [the documentation for the k8s-service helm
chart](https://github.com/gruntwork-io/helm-kubernetes-services/tree/master/charts/k8s-service#how-do-i-set-and-share-configurations-with-the-application).

To configure your application with `ConfigMaps`, use the `configmaps_as_volumes` and `configmaps_as_env_vars` input
variables. For `Secrets`, use the `secrets_as_volumes` and `secrets_as_env_vars` input variables. Note that all 4 input
variables assume that the `ConfigMap` or `Secret` is already created and configured. This module does not manage either
resources internally.

## How do I debug my configuration?

Sometimes you may pass in malformed or incompatible input variables into this module that causes Helm or the Kubernetes
API to fail schema validations. In these situations, it is oftentimes useful to see the actual `values.yaml` file that
is passed in to Helm on deploy. You can use the `values_file_path` input variable to generate the `values.yaml` file.
Then, you can debug the generated yaml files using the `helm template` command:

```
helm template $APPLICATION_NAME gruntwork/k8s-service --debug -f $VALUES_FILE_PATH
```

## How do I create a canary deployment?

You may optionally configure a [canary deployment](https://martinfowler.com/bliki/CanaryRelease.html) of an arbitrary
tag that will run as an individual deployment behind your configured service. This is useful for ensuring a new
application tag runs without issues prior to fully rolling it out.

Use the `desired_number_of_canary_pods` and `canary_image` input variables to configure the canary deployment. The
canary `Pods` are automatically included in the `Service` that exposes the `Pods`.
