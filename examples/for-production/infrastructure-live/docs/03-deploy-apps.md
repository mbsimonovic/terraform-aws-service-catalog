# How To Deploy A Docker Service

In the previous section, you learned how to [authenticate to AWS via web, CLI, VPN, and SSH](02-authenticate.md). In
this guide, we'll walk you through deploying a Dockerized app to the  cluster running in your Reference
Architecture.

* [What's already deployed](#whats-already-deployed)
* [The App](#the-app)
* [Dockerizing](#dockerizing)
* [Publishing your docker image](#publishing-your-docker-image)




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









## Next steps

Next up, it's time to [configure Gruntwork Pipelines (CI / CD)](04-configure-gw-pipelines.md) for your app code and infrastructure code.
