# How To Deploy A Docker Service

In the previous section, you learned how to [authenticate to AWS via web, CLI, VPN, and SSH](02-authenticate.md). In
this guide, we'll walk you through deploying a Dockerized app to the  cluster running in your Reference
Architecture.

* [What's already deployed](#whats-already-deployed)
* [The App](#the-app)
* [Dockerizing](#dockerizing)
* [Publishing your docker image](#publishing-your-docker-image)
* [Deploying to an EKS cluster](#deploying-to-an-eks-cluster)
  * [Setting up the Kubernetes Service](#setting-up-the-kubernetes-service)
  * [Deploying your configuration](#deploying-your-configuration)
  * [Monitoring your deployment progress](#monitoring-your-deployment-progress)
* [Debugging errors](#debugging-errors)
  * [Using kubectl](#using-kubectl)
  * [Cloudwatch Logs](#cloudwatch-logs)




## What's already deployed

When Gruntwork initially deploys the Reference Architecture, we deploy the
[aws-sample-app](https://github.com/gruntwork-io/aws-sample-app/) into it, configured both as a frontend (i.e.,
user-facing app that returns HTML) and as a backend (i.e., an app that's only accessible internally and returns JSON).
We recommend checking out the [aws-sample-app](https://github.com/gruntwork-io/aws-sample-app/) as it is designed to
deploy seamlessly into the Reference Architecture and demonstrates many important patterns you may wish to follow in
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

In order to deploy the app on ECS, we need to dockerize the app. If you are not familiar with the basics of docker, we
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

First, you'll need to create the new ECR repository.

1. Create a new branch on your infrastructure-live repository: `git checkout -b simple-web-app-repo`.
1. Open [`repos.yml` in
`shared/us-west-2/_regional/ecr-repos`](../shared/us-west-2/_regional/ecr-repos/repos.yml) and
add the desired repository name of your app. For the purposes of our example, let's call
ours `simple-web-app`:

```yaml
simple-web-app:
  external_account_ids_with_read_access:
  # NOTE: we have to comment out the directives so that the python based data merger (see the `merge-data` hook under
  # blueprints in this repository) can parse this yaml file. This still works when feeding through templatefile, as it
  # will interleave blank comments with the list items, which yaml handles gracefully.
  # %{ for account in accounts }
  - '${account}'
  # %{ endfor }
  external_account_ids_with_write_access: []
  tags: {}
  enable_automatic_image_scanning: true
```

1. Commit and push the change:

```
git add shared/us-west-2/shared/data-stores/ecr-repos/terragrunt.hcl && git commit -m 'Added simple-web-app repo' && git push
```
1. Now open a pull request on the `simple-web-app-repo` branch.


This will cause the ECS deploy runner pipeline to run a `terragrunt plan`. If the plan output looks correct with no errors, somebody can review and approve the PR. Once approved, you can merge, which will kick off a `terragrunt apply` on the deploy runner, creating the repo. Follow the progress through your CI server.

Once the repository exists, you can use it with the Docker image.Each repo in ECR has a URL of the format `<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<REPO_NAME>`. For example, for the `shared-services` account
with ID `234567890123`, an ECR repo in `us-west-2`, and an app called `simple-web-app`, the registry URL would be:

```
234567890123.dkr.ecr.us-west-2.amazonaws.com/simple-web-app
```

You can create a Docker image for this repo, with a `v1` label, as follows:

```bash
docker tag simple-web-app:latest 234567890123.dkr.ecr.us-west-2.amazonaws.com/simple-web-app:v1
```

Next, authenticate your Docker client with ECR in the shared-services account:

```bash
aws ecr get-login-password --region "us-west-2"  | docker login --username AWS --password-stdin 234567890123.dkr.ecr.us-east-1.amazonaws.com
```

And finally, push your newly tagged image to publish it:

```bash
docker push 234567890123.dkr.ecr.us-west-2.amazonaws.com/simple-web-app:v1
```







## Deploying to an EKS cluster

Now that you have the Docker image of your app published, the next step is to deploy it to your EKS Cluster that was
set up as part of your reference architecture deployment.

### Setting up the Kubernetes Service

The next step is to create a `terragrunt.hcl` file to deploy your app in each app environment (i.e. in dev, stage,
prod). For example, for the `stage` environment, create a `simple-web-app` folder in
[stage/us-west-2/stage/services](../stage/us-west-2/stage/services). Next, you can copy over the contents of the
[sample-app-frontend terragrunt.hcl](../stage/us-west-2/stage/services/sample-app-frontend/terragrunt.hcl) so you have
something to start with.

With the `terragrunt.hcl` file open, update the following:

* Set the `service_name` local to your desired name: e.g., `simple-web-app-stage`.
* Remove the unneeded `tls_secrets_manager_arn` local (we are not configuring the service with a dedicated TLS certificate).
* In the `container_image` object, set `repository` to the repo url of the just published Docker image: e.g., `234567890123.dkr.ecr.us-west-2.amazonaws.com/simple-web-app`. Also make sure to update the `tag` attribute to the appropriate image tag to deploy.
* Update the `domain_name` to configure a DNS entry for the service: e.g., `simple-web-app.${local.account_vars.local.domain_name.name}`.
* Remove the `scratch_paths` configuration, as our simple web app does not pull in secrets dynamically.
* Remove all environment variables, leaving only an empty map: e.g. `env_vars = {}`.
* Update health check paths to reflect our new service:
    * `alb_health_check_path`
    * `liveness_probe_path`
    * `readiness_probe_path`

* Remove configurations for IAM role service account binding, as our app won't be communicating with AWS:
    * `service_account_name`
    * `iam_role_name`
    * `eks_iam_role_for_service_accounts_config`
    * `iam_role_exists`
    * `iam_policy`


### Deploying your configuration

The above are the minimum set of configurations that you need to deploy the app. You can take a look at [`variables.tf`
of `k8s-service`](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/master/modules/services/k8s-service)
for all the available options.

Once you've verified that everything looks fine, change to the new `services/simple-web-app` folder, and run

```bash
terragrunt apply
```

This will show you the plan for deploying your new service. Verify the plan looks correct, and then approvie it to apply
your application configuration, which will create a new Kubernetes Deployment to schedule the Pods. In the process,
Kubernetes will allocate:

- A `Service` resource to expose the Pods under a static IP within the Kubernetes cluster.
- An `Ingress` resource to expose the Pods externally under an ALB.
- A Route 53 Subdomain that binds to the ALB endpoint.

Once the service is fully deployed, you can hit the configured DNS entry to reach your service.


### Monitoring your deployment progress

Due to the asynchronous nature of Kubernetes deployments, a successful `terragrunt apply` does not always mean your app
was deployed successfully. The following commands will help you examine the deployment progress from the CLI.

First, if you haven't done so already, configure your `kubectl` client to access the EKS cluster. You can follow the
instructions [in this section of the
docs](https://github.com/gruntwork-io/terraform-aws-eks/blob/master/core-concepts.md#how-do-i-authenticate-kubectl-to-the-eks-cluster)
to configure `kubectl`. For this guide, we will use [kubergrunt](https://github.com/gruntwork-io/kubergrunt):

```
kubergrunt eks configure --eks-cluster-arn ARN_OF_EKS_CLUSTER
```

Once `kubectl` is configured, you can query the list of deployments:

```
kubectl get deployments --namespace applications
```

The list of deployments should include the new `simple-web-app` service you created. This will show you basic status
info of the deployment:

```
NAME             DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
simple-web-app   3         3         3            3           5m
```

A stable deployment is indicated by all statuses showing the same counts. You can get more detailed information about a
deployment using the `describe deployments` command if the numbers are not aligned:

```
kubectl describe deployments simple-web-app --namespace applications
```

See the [How do I check the status of a
rollout?](https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/charts/k8s-service/README.md#how-do-i-check-the-status-of-the-rollout)
documentation for more information on getting detailed information about Kubernetes Deployments.

## Debugging errors

Sometimes, things don't go as planned. And when that happens, it's always beneficial to know how to locate the
source of the problem. There are two places you can look for information about a failed Pod.

### Using kubectl

The `kubectl` CLI is a powerful tool that helps you investigate 
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

You can also retrieve logs from a `Pod` (`stdout` and `stderr`) using `kubectl`:

```
kubectl logs $POD_NAME -n $POD_NAMESPACE
```

Most cluster level issues (e.g if there is not enough capacity to schedule the `Pod`) can be triaged with this
information. However, if there are issues booting up the `Pod` or if the problems lie in your application code, you will
need to dig into the logs.

### CloudWatch Logs

By default, all the container logs from a `Pod` (`stdout` and `stderr`) are sent to CloudWatch Logs. This is ideal for
debugging situations where the container starts successfully but the service doesn't work as expected. Let's assume our
`simple-web-app` containers started successfully (which they did!) but for some reason our requests to those containers
are timing out or returning wrong content.

1. Go to the "Logs" section of the [Cloudwatch Management Console](https://console.aws.amazon.com/cloudwatch/) and look for the name of the EKS cluster in the table.

1. Clicking it should take you to a new page that displays a list of entries. Each of these correspond to a `Pod` in the
   cluster, and contain the `Pod` name. Look for the one that corresponds to the failing `Pod` and click it.


1. You should be presented with a real-time log stream of the container. If your app logs to STDOUT, its logs will show
   up here. You can export the logs and analyze it in your preferred tool or use [CloudWatch Log
   Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html) to query the logs directly
   in the AWS web console.




## Next steps

Next up, it's time to [configure Gruntwork Pipelines (CI / CD)](04-configure-gw-pipelines.md) for your app code and infrastructure code.
