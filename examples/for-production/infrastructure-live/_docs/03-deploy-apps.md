# How To Deploy A Docker Service

In the previous section, you learned how to [authenticate to AWS via web, CLI, VPN, SSH, and 
Kubernetes](02-authenticate.md). In this guide, we'll walk you through deploying a Dockerized app to the EKS cluster 
running in your Reference Architecture.

* [What's already deployed](#whats-already-deployed)
* [The App](#the-app)
* [Dockerizing](#dockerizing)
* [Publishing your docker image](#publishing-your-docker-image)
* [Deploying to a cluster](#deploying-to-a-cluster)
  * [Service Configuration](#service-configuration)
  * [Ingress Configuration](#ingress-configuration)
  * [Deploying your configuration](#deploying-your-configuration)
  * [Monitoring your deployment progress](#monitoring-your-deployment-progress)
* [Debugging errors](#debugging-errors)
  * [Using kubectl](#using-kubectl)
  * [CloudWatch Logs](#cloudwatch-logs)




## What's already deployed

When Gruntwork initially deploys the Reference Architecture, we deploy the 
[aws-sample-app](https://github.com/gruntwork-io/aws-sample-app/) into it, configured both as a frontend (i.e., 
user-facing app that returns HTML) and as a backend (i.e., an app that's only accessible internally and returns JSON).
We recommend checking out the [aws-sample-app](https://github.com/gruntwork-io/aws-sample-app/) as it is designed to
deploy seamlessly into the Reference Archiecture and demonstrates many important patterns you may wish to follow in 
your own apps, such as how to package your app using Docker or Packer, do service discovery for microservices and data 
stores in a way that works in dev and prod, securely manage secrets such as database credentials and self-signed TLS 
certificates, automatically apply schema migrations to a database, and so on.

However, for the purposes of this guide, we will create a much simpler app from scratch so you can see how all the 
pieces fit together. Start with this simple app, and then, when you're ready, start adopting the more advanced
practices from [aws-sample-app](https://github.com/gruntwork-io/aws-sample-app/).




## The App

For this guide, we'll use a simple Node.js app as an example, but the same principles can be applied to any app:

```js
const express = require('express');

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

// App
const app = express();
app.get('/simple-web-app', (req, res) => {
  res.send('Hello world\n');
});

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
```

That's it! It's a classic express "Hello World" starter app that listens for requests on port `8080`. For this example
walkthrough, save this file as `server.js`.

Since we need to pull in the dependencies to run this app, we will also need a corresponding `package.json`:

```js
{
  "name": "docker_web_app",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.16.1"
  }
}
```




## Dockerizing

In order to deploy the app on EKS, we need to dockerize the app. If you are not familiar with the basics of docker, we 
recommend you check out our "Crash Course on Docker and Packer" from the [Gruntwork Training 
Library](https://training.gruntwork.io/p/a-crash-course-on-docker-packer).

For this guide, we will use the following `Dockerfile` to package our app into a container (see [Docker 
samples](https://docs.docker.com/samples/) for how to Dockerize many popular app formats):

```docker
FROM node:8

# Create app directory
WORKDIR /usr/app

COPY package*.json ./

RUN npm install
COPY . .

EXPOSE 8080
CMD [ "npm", "start" ]
```

The folder structure of our sample app looks like this:

```shell
├── server.js
├── Dockerfile
└── package.json
```

Your actual app will be more complicated than this, but the main point to take from here is that we need to ensure our 
Docker image is configured to `EXPOSE` the port that our app is going to need for external communication. 

To build this Docker image from the `Dockerfile`, run:

```bash
docker build -t simple-web-app:latest .
```

Now you can test the container to see if it is working:

```bash
docker run --rm -p 8080:8080 simple-web-app:latest
```

This starts the newly built container and links port `8080` on your machine to the container's port `8080`. You should
see output like below when you run this command:

```
> docker_web_app@1.0.0 start /usr/app
> node server.js

Running on http://0.0.0.0:8080
```

You should now be able to hit the app by opening `localhost:8080` in your browser. Try it out to verify you get the
"Hello world" message from the server.

Some things to note when writing up your `Dockerfile` and building your app:

* Ensure your `Dockerfile` starts your app in the foreground so the container doesn't shutdown after app startup.
* Your app should log to `stdout` / `stderr` to aid in [debugging](#debugging-errors) it after deployment to AWS.




## Publishing your docker image

Once you've verified that you can build your app's docker image without any errors, the next step is to publish those 
images to an [ECR repo](https://aws.amazon.com/ecr/). All ECR repos are managed in the `shared-services` AWS account.

To add a new repo, open [`terragrunt.hcl` in 
`shared/eu-west-1/shared/data-stores/ecr-repos`](../shared/eu-west-1/shared/data-stores/ecr-repos/terragrunt.hcl) and 
add the desired repository name of your app to the `repositories` list. For the purposes of our example, let's call 
ours `simple-web-app`: 

```hcl
inputs = {
  repositories = {
    "simple-web-app" = {
      tags                            = {}
      enable_automatic_image_scanning = true

      # Use default settings for cross account access
      external_account_ids_with_read_access  = null
      external_account_ids_with_write_access = null
    }
  }
}
```


Next, [authenticate](02-authenticate.md) to the `shared-services` account and run the following command to deploy your
changes:

```bash
terragrunt apply
```

This will create an ECR repo with the name you specified in the `shared-services` account. Each repo in ECR has a URL 
of the format `<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<REPO_NAME>`. For example, for the `shared-services` account 
with ID `111122223333`, an ECR repo in `eu-west-1`, and an app called `simple-web-app`, the registry URL would be:

```
111122223333.dkr.ecr.eu-west-1.amazonaws.com/simple-web-app
```

You can create a Docker image for this repo, with a `v1` label, as follows:

```bash
docker tag simple-web-app:latest 111122223333.dkr.ecr.eu-west-1.amazonaws.com/simple-web-app:v1
```

Next, authenticate your Docker client with to ECR in the shared-services account:

```bash
eval $(aws ecr get-login --region "eu-west-1" --no-include-email --registry-ids "111122223333")
```

And finallyl, push your newly tagged image to publish it:

```bash
docker push 111122223333.dkr.ecr.eu-west-1.amazonaws.com/simple-web-app:v1
```




## Deploying to a cluster

Now that you have the Docker image of your app published, the next step is to deploy it to your EKS Cluster that was 
set up as part of your reference architecture deployment.

The first step is to create a `terragrunt.hcl` file to deploy your app in each app environment (i.e. in dev, stage, 
prod). For example, for the `stage` environment, create a `simple-web-app` folder in 
[stage/eu-west-1/stage/services](../stage/eu-west-1/stage/services). Next, you can copy over the contents of the 
[sample-app-frontend terragrunt.hcl](../stage/eu-west-1/stage/services/sample-app-frontend/terragrunt.hcl) so you have 
something to start with.

### Service Configuration

Still in the `simple-web-app` folder, open the `terragrunt.hcl` file, and update the following parameters:

* Set `service_name` to your desired name: e.g., `simple-web-app-stage`.
* Set `image` to the repo url of the just published Docker image: e.g., `111122223333.dkr.ecr.eu-west-1.amazonaws.com/simple-web-app`
* Set `desired_number_of_pods` to the number of tasks of your app you want EKS to spawn: e.g., `2`.
* Set `container_port` to the port your container exposes: e.g., `8080`.

### Ingress Configuration

When deployed, the actual containers are run as `Pods` on the EKS cluster, which are scheduled to the worker nodes.
Within the cluster, services can communicate with each other using the `Service` endpoints which are automatically
provisioned by the underlying terraform modules. However, these endpoints are not accessible outside of the cluster.

You can use `Ingress` resources to expose your `Service` to be accessible outside of Kubernetes. `Ingress` resources
manage and configure AWS ALBs that eventually lead to the `Service` endpoint. These resources are configured by the
module using the `ingress_config` input variable.

For example, to expose an ALB that maps the path `/simple-web-app` to our `Service`, you can set the `ingress_config`
variable to:

```hcl
ingress_config = {
  path = "/simple-web-app"
}
```

This will create an `Ingress` resource for the `simple-web-app` that will map to an ALB in our environment. This ALB
will expose port `80` and forward any requests that hit the path `/simple-web-app` to our container on the port we
defined in `container_port`, which is `8080`.

You can query the `Ingress` endpoint using `kubectl` once the app is deployed:

```
kubectl get ingresses \
    -l "app.kubernetes.io/name=simple-web-app,app.kubernetes.io/instance=simple-web-app" \
    -o jsonpath \
    --template '{.items[0].status.loadBalancer.ingress[0].hostname}'
```

This will output the `Ingress` endpoint to the console. You should then be able to hit it to reach your deployed app -
i.e. `http://$INGRESS_ENDPOINT/simple-web-app`.

#### Route 53 Domain Records

Your EKS cluster is deployed with [external-dns](https://github.com/kubernetes-incubator/external-dns) installed. This
will automatically map hostnames configured on the `Ingress` resource to existing Route 53 Hosted Zones to link the
domain name to the provisioned ALBs.

For example, to make the `simple-web-app` available under the domain `simple-web-app.gruntwork.io`,
you can set the `ingress_config` to be:

```hcl
ingress_config = {
  path = "/"
  host = "simple-web-app.gruntwork.io"
}
```

When applied, this will not only provision the ALB, but also create a new subdomain record for `simple-web-app` for the
corresponding Route 53 Hosted Zone for the domain `gruntwork.io`
to map to the new ALB.

#### TLS configuration

The cluster will also autodiscover any ACM TLS certificates that support the chosen domain. For example, the Reference
Architecture comes with ACM TLS certificates for all subdomains of the domain names used for the sample app frontend in
each environment. This means that if you use any subdomain on those host names for the Route 53 record, the
corresponding ACM certificates will be automatically associated with the ALB. This also works for private domain names
as well, provided that you create the ACM certificates and Route 53 Hosted Zones.

Note that for TLS to function properly, you need to set the `ingress_listener_ports` to accept HTTPS:

```hcl
ingress_listener_ports = [
  {
    HTTPS = 443
  }
]
```


### Deploying your configuration

The above are the minimum set of configurations that you need to deploy the app. You can take a look [`variables.tf` 
of `k8s-service`](https://github.com/gruntwork-io/aws-service-catalog/tree/master/modules/services/k8s-service)
for all options.

Once you've verified that everything looks fine, run:

```bash
terragrunt apply
```

This will apply your configuration to the cluster and deploy your app.


### Monitoring your deployment progress

Due to the asynchronous nature of Kubernetes deployments, a successful `terragrunt apply` does not always mean your app
was deployed successfully. There are several resources that need to rollout in Kubernetes before your application is
available:

- The `Pods` associated with the `Deployment`.
- The ALB that fulfills the `Ingress` endpoint (if applicable).
- The DNS record that maps to the `Ingress` endpoint (if applicable).

Once `terragrunt apply` completes, you can use `kubectl` to monitor the status of the rollout.

#### Monitoring Deployment rollout

`Deployment` resources define controllers in Kubernetes that ensure the state of the cluster matches the desired state
as described in the manifest. This is handled asynchronously after the changes have been applied to the manifest
configuration. You can use the `rollout status` command of `kubectl` to watch and wait for the rollout to complete:

```bash
# First get the name of the deployment object
DEPLOYMENT_NAME=$(kubectl get deployments \
    -l "app.kubernetes.io/name=simple-web-app,app.kubernetes.io/instance=simple-web-app" \
    --all-namespaces \
    -o jsonpath \
    --template '{.items[0].metadata.name}')
# Then, wait for the rollout to complete
kubectl rollout status deployment/"$DEPLOYMENT_NAME" -w
```

This will print out the status of the rollout in the context of how many `Pods` have been launched using the current
configuration. The command will only finish if the rollout completes successfully.

A completed rollout indicates that all the `Pods` associated with the `Deployment` has been successfully started, and
that they all reach the `Ready` status. This indicates that the `Pods` can start serving traffic (if they are network
services), or can begin running workloads (if they are backend task workers).

#### Monitoring Ingress endpoints

A successful rollout for a `Deployment` indicates the `Pods` are ready to accept traffic, but it does not mean that all
the endpoints have been allocated. The endpoint to access the service is managed by the `Ingress` resource. The
`Ingress` resource is then materialized into ALBs by the ALB Ingress controller that is deployed on to your EKS cluster.
Unfortunately, since the endpoint is backed by an actual Load Balancer in the cloud, it takes time for it to be
provisioned after the resource is created.

You can use `kubergrunt` to monitor and wait for the `Ingress` endpoint to be provisioned, similar to the `Deployment`.
In order to monitor the `Ingress` endpoint, we need to know two things:

- The name of the `Ingress` resource. The `Ingress` resource is named by combining the `helm` release name and the
  application name. Our module uses the application name for both, so in this case will be named
  `simple-web-app-simple-web-app`.
- The `Namespace` where the `Ingress` resource is deployed. For this example, we used the `applications` `Namespace` to
  deploy our app.


```bash
INGRESS_NAME=simple-web-app-simple-web-app
INGRESS_NAMESPACE=applications
kubergrunt k8s wait-for-ingress \
    --namespace "$INGRESS_NAMESPACE" \
    --ingress-name "$INGRESS_NAME"
```

This command will continuously monitor the `Ingress` resource until the ALB is provisioned and the endpoint is updated
on the resource. Note that this command will time out after 5 minutes. You can configure the timeout settings using the
`--max-retries` and `--sleep-between-retries` CLI args.

If the command successfully completes, then the `Ingress` endpoint is provisioned and attached to the resource. You can
query the endpoint by looking up the `Ingress` resource:

```bash
kubectl describe ingress "$INGRESS_NAME" -n "$INGRESS_NAMESPACE"
```

This will list out the endpoints and attached host rules of the `Ingress` resource. If you used a path based `Ingress`
configuration without hosts, you should be able to hit the endpoint directly to access the service.

For host based `Ingress` configuration, the Route 53 DNS records need to be updated to point to the `Ingress` endpoint,
so that the routing works. The EKS cluster in the reference architecture is deployed with the `external-dns`
application, which will automatically update the records. In this setup, you should be able to hit the hostname to
access the service without having to do anything else.

##### Searching for the Ingress Resource

If you happen to not know the name or `Namespace` of the `Ingress` resource, you can look it up using `kubectl`. There
are multiple approaches to filter down the resources. For example, you can start by listing out all `Ingress` resources
in the cluster:

```bash
kubectl get ingresses --all-namespaces
```

Then, narrow down your search by using the list of names and `Namespaces` as a clue. You can get more information about
a particular `Ingress` resource given its name and `Namespace`:

```bash
kubectl describe ingress "$INGRESS_NAME" -n "$INGRESS_NAMESPACE"
```

You can also use labels to search for the `Ingress` resource. For example, if you know the application name that you
deployed, you can search for all `Ingress` resources that are labeled with that application name:

```bash
kubectl get ingresses \
    -l "app.kubernetes.io/name=simple-web-app" \
    --all-namespaces
```




## Debugging errors

Sometimes, things don't go as planned. And when that happens, it's always beneficial to know how to locate the
source of the problem. There are two places you can look for information about a failed Pod.


### Using kubectl

By now you should be familiar with the `kubectl` CLI, and how powerful it is. You can use `kubectl` to investigate
problems with your `Pods`.

The first step is to obtain the metadata and status of the `Pods`. To lookup information about a `Pod`, retrieve them
using `kubectl`:

```bash
kubectl get pods \
    -l "app.kubernetes.io/name=simple-web-app,app.kubernetes.io/instance=simple-web-app" \
    --all-namespaces
```

This will list out all the associated `Pods` with the deployment you just made. Note that this will show you a minimal
set of information about the `Pod`. However, this is a useful way to quickly scan the scope of the damage:

- How many `Pods` are available? Are all of them failing or just a small few?
- Are the `Pods` in a crash loop? Have they booted up successfully?
- Are the `Pods` passing health checks?

Once you can locate your failing `Pods`, you can dig deeper by using `describe pod` to get more information about a
single `Pod`. To do this, you will first need to obtain the `Namespace` and name for the `Pod`. This information should
be available in the previous command. Using that information, you can run:

```bash
kubectl describe pod $POD_NAME -n $POD_NAMESPACE
```

to output the detailed information. This includes the event logs, which indicate additional information about any
failures that has happened to the `Pod`.

Most cluster level issues (e.g if there is not enough capacity to schedule the `Pod`) can be triaged with this
information. However, if there are issues booting up the `Pod` or if the problems lie in your application code, you will
need to dig into the logs.


### CloudWatch Logs

By default, all the container logs from a `Pod` (`stdout` and `stderr`) are sent to CloudWatch Logs. This is ideal for
debugging situations where the container starts successfully but the service doesn't work as expected. Let's assume our
`simple-web-app` containers started successfully (which they did!) but for some reason our requests to those containers
are timing out or returning wrong content.

1. Go to the "Logs" section of the [Cloudwatch Management Console](https://console.aws.amazon.com/cloudwatch/) and look 
   for the name of the EKS cluster in the table.

1. Clicking it should take you to a new page that displays a list of entries. Each of these correspond to a `Pod` in the
   cluster, and contain the `Pod` name. Look for the one that corresponds to the failing `Pod` and click it.

1. You should be presented with a real-time log stream of the container. If your app logs to `stdout`, its logs will 
   show up here. You can export the logs and analyze it in your preferred tool or use [CloudWatch Log
   Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html) to query the logs directly
   in the AWS web console.




## Next steps

Next up, you'll learn how to [configure CI / CD for your app code and infrastructure code](04-configure-ci-cd.md).
