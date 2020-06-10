# Background

## Should I use Route 53 or Cloud Map?

AWS Cloud Map allows you to bind domain names to resources in the cloud, such as databases, EC2 instances, ECS
containers, Kubernetes Pods, etc. Under the hood Cloud Map uses Route 53 Hosted Zones to manage the DNS records for each
name that is bound. However, unlike Route 53, Cloud Map provides resource discovery capabilities that allow you to
dynamically add and remove resource addresses under the name as they are updated. For example, using the Service
Discovery APIs of Cloud Map, you can bind the individual IPs of each ECS task in an ECS service to the domain name
without having a Load Balancer inbetween. Furthermore, Cloud Map has a lower TTL for DNS propagating so that updates are
reflected in a timely manner.

On the other hand, Cloud Map is focused on resource service discovery. That is, it does not give you the full range of
capabilities to manage your DNS entries, like setting up TXT records and MX records.

Given that, Cloud Map is optimized for service discovery where the resource targets live in AWS and dynamically change
frequently (e.g., direct mappings to containers in ECS or EKS), while directly working with Route 53 hosted zones will
give you the full range of control over the DNS records for all situations that require domain names (e.g., setting up a
mail server).

Here is a summary of the capabilities:

| Feature                      | Route 53 | Cloud Map                          |
|------------------------------|----------|------------------------------------|
| DNS controls                 | Full     | Limited (A and CNAME records only) |
| DNS based service discovery  | Yes      | Yes                                |
| Automatic resource discovery | No       | Yes                                |
| Quick propagation            | No       | Yes                                |
|------------------------------|----------|------------------------------------|
