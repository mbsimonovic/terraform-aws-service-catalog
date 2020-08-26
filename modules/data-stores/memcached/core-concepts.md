## How do I use Kubernetes Service Discovery with the ElastiCache Memcached Cluster?

You can register the ElastiCache Memcached endpoints to the internal DNS service used by Kubernetes by creating a Kubernetes
[Service resource](https://kubernetes.io/docs/concepts/services-networking/service/) of type
[ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname) that can be used to route
requests against the nodes within the cluster. We recommend using the Service DNS Mapping
feature of the [eks-core-services module](../../services/eks-core-services) to bind the endpoints of the Memcached cluster
to a Kubernetes Service. See the [relevant
documentation](../../services/eks-core-services/core-concepts.md#how-do-i-register-external-services-to-internal-dns)
for more information.
