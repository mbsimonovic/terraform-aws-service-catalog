## How do I hook up the cluster autoscaler to my workers?

When you create the EKS cluster using the [eks-cluster module](../eks-cluster), you have the option of including self
managed workers as a default worker pool for your Pods. The module exposes an input variable
`autoscaling_group_include_autoscaler_discovery_tags` which is used to control whether or not that initial group of
worker ASGs should be tagged with a set of discovery tags that are used by the cluster autoscaler. If that variable is
set to `true`, all the ASGs created in the module will be included in the cluster autoscaler pool for scale up and scale
down events.

## How do I restrict which Hosted Zones the app should manage?

If you have certain hosted zones that are considered protected and require more control over the DNS records, you can
restrict the application to only manage the Hosted Zones that you explicitly want it to. To specify the zones that the
app should manage, use the `external_dns_route53_hosted_zone_id_filters` and
`external_dns_route53_hosted_zone_domain_filters` input variables. The former specifies zones by ID, while the latter
specifies zones by name.

For example, if you want the app to only manage hosted zones that end with the name `k8s.local`, you can set
`external_dns_route53_hosted_zone_domain_filters = ["k8s.local"]` in your input variables. This means that the app will
only create records for any hostnames on `Ingress` resources that end with the domain `k8s.local`, and ignore all
others, even if there exists corresponding Route 53 Hosted Zones.
