## How do I use Kubernetes Service Discovery with the RDS Database?

You can register the RDS database endpoint to the internal DNS service used by Kubernetes by creating a Kubernetes
[Service resource](https://kubernetes.io/docs/concepts/services-networking/service/) of type
[ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname) that can be used to route
requests against that Service to the primary endpoint of the RDS database. We recommend using the Service DNS Mapping
feature of the [eks-core-services module](../../services/eks-core-services) to bind the primary endpoint of the RDS
database to a Kubernetes Service. See the [relevant
documentation](../../services/eks-core-services/core-concepts.md#how-do-i-register-external-services-to-internal-dns)
for more information.
