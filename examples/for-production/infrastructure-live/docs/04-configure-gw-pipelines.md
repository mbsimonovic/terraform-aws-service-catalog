# Configure Gruntwork Pipelines

In the previous section, you saw [how to deploy your apps into the Reference Architecture](03-deploy-apps.md). Now it's
time to see how to configure a CI / CD pipeline to automate deployments.

If you are not familiar with Gruntwork Pipelines, you can learn more by reading the Gruntwork Production Deployment Guide
[How to configure a production-grade CI-CD workflow for infrastructure
code](https://gruntwork.io/guides/automations/how-to-configure-a-production-grade-ci-cd-setup-for-apps-and-infrastructure-code/).

* [CI / CD pipeline for infrastructure code](#ci--cd-pipeline-for-infrastructure-code): How to configure a CI / CD
  pipeline for infrastructure code, such as Terraform modules that configure your VPCs, databases, DNS settings, etc.

* [CI / CD pipeline for app code](#ci--cd-pipeline-for-app-code): How to configure a CI / CD pipeline for application
  code, such as a Ruby, Python, PHP, or Java web service packaged with Packer or Docker.


## CI / CD pipeline for infrastructure code

This diagram shows a rough overview of the Gruntwork Pipelines architecture:

![Architecture Diagram](images/gruntwork-pipelines-architecture.png)

The Gruntwork Pipelines workflow, defined in [`.circleci/config.yml`](/.circleci/config.yml), works like this:

- A CI server is hooked up to watch for changes in your `infrastructure-live` repository.
- Every time a new commit is pushed, the CI server looks for modules that have changed in the repository.
- For each module that changed, trigger a `plan` action on the module by invoking the ECS deploy runner.
- The ECS deploy runner is invoked using an AWS Lambda function that exposes a limited range of actions that can be
  performed in a deploy container that has all the necessary tools installed.
- The infrastructure code runs from within a Docker container in an ECS task on Fargate. This task is what has the
  powerful AWS credentials to deploy infrastructure.
- If the job was triggered on the `main` branch of the repository, the CI server will run `plan`.
- If the Slack integration is set up, a notification will be sent to the Slack channel that the job is awaiting
approval.
- Once the job is manually approved. the CI server will run `apply`. The Slack integration will post a notification
about whether the apply failed or succeeded.

### Set up the pipeline in your own organization
First make sure you've copied the repo into your own GitHub organization, as `infrastructure-live`. The CircleCI job is already configured in `<YOUR_REPO_ROOT>/.circleci/config.yml`. Here are the additional steps to get the job running successfully:

#### View the failed job
1. Login to CircleCI.
1. Switch to your company's GitHub organization using the left panel.

   ![CircleCI Switch Organizations](images/circleci-setup/circleci_switch_orgs.gif)

1. Switch to the Projects tab using the left panel.
1. Search for your infrastructure-live repository and click **Set Up Project.**
1. Click **Start Building**.

You should see a job kicked off that failed.

   ![CircleCI Failed Job](images/circleci-setup/circleci_failed_job.png)

We'll now fix this job so that it passes, by adding some Environment Variables that are missing.

#### Get the machine user credentials from AWS
1. Log into the Security account in the AWS Console.
1. Go into IAM and find the ci-machine-user under Users.
1. Go to Security Credentials > Access Keys > Create Access Key.
1. Save these values as the `AWS_ACCESS_KEY_ID` and the `AWS_SECRET_ACCESS_KEY` Environment Variables in CircleCI.

#### CircleCI Environment Variables
1. Login to CircleCI.
1. Go into your project again, so you see the list of failed builds.
1. Click on **Project Settings** (the upper right button, above **Auto-expand**).
1. Click on **Environment Variables** and configure the following environment variables:

| Env var name | Value |
| --- | --- |
| AWS_ACCESS_KEY_ID | The Access Key generated for the machine user in the Security account. |
| AWS_SECRET_ACCESS_KEY | The Secret Key generated for the machine user in the Security account. |
| GITHUB_OAUTH_TOKEN | Enter the MachineUserGitHubPAT here. You can find this in [`reference-architecture-form.yml`](reference-architecture-form.yml) or in the shared account's Secrets Manager. |

#### Set up the Slack integration

1. Create a Slack App
    1. Visit [your apps](https://api.slack.com/apps) on the Slack API website, and click `Create New App`.
    1. Name your application (e.g., `CircleCI` or `CircleCI-Pipeline`).
    1. Then select the Slack workspace in which to install this app.
1. Set Permissions
    1. On the next page select the "Permissions" area, and add these 3 "scopes".
        * chat:write
        * chat:write.public
        * files:write

   ![Slack App Scopes](images/circleci-setup/slack_app_scopes.png)
1. Install and Receive Token
    1. Install the application into the Slack workspace and save your OAuth Access Token. This will be used in
       a CircleCI environment variable.

   ![Slack OAuth Tokens](images/circleci-setup/slack_oauth_tokens.png)

   ![Slack OAuth Access Token](images/circleci-setup/slack_auth_token_key.png)
1. Choose a Slack channel to notify
    1. Choose or create a Slack channel in your workspace to notify with pipeline updates.
    1. Right-click the channel name. You'll see a context menu.
    1. Select `Copy link`.
    1. Extract the Channel ID from the URL copied. E.g., `https://<org>.slack.com/archives/<CHANNEL_ID>`
1. Create env vars on CircleCI
    1. Login to CircleCI. Navigate to **Project Settings** -> **Environment Variables**.
    1. Configure the following environment variables:

| Env var name | Value |
| --- | --- |
| SLACK_ACCESS_TOKEN | The OAuth token acquired through the previous step. |
| SLACK_DEFAULT_CHANNEL | If no channel ID is specified, the app will attempt to post here. |

#### Verify the job succeeds
1. On the project build page, rerun the failed job using the icons to the right of the job.
1. The `plan` step should succeed. Since the job is happening on the `main` branch, the job should hit the
`hold` phase and wait for your approval.

   ![CircleCI Jobs](images/circleci-setup/circleci_jobs.png)

1. You should get a Slack notification telling you the plan succeeded and that the job is being held for
approval.

   ![Slack Plan Notification](images/circleci-setup/circleci_slack_plan.png)

1. Approve the job.

   ![CircleCI Approve Job](images/circleci-setup/circleci_approve_job.png)

1. The job should succeed!

   ![CircleCI Job Fixed](images/circleci-setup/circleci_fixed.png)

1. You should also get a Slack notification that the apply succeeded.

   ![Slack Apply Notification](images/circleci-setup/circleci_slack_apply.png)




## CI / CD pipeline for app code

The Reference Architecture also includes configuration files for setting up a CI / CD pipeline for your application code.
You can find configurations for application CI / CD in the folder `_ci/app-templates`:

```
_ci/app-templates
├── .circleci
│   └── config.yml
└── scripts
    ├── build-docker-image.sh
    ├── constants.sh
    ├── deploy-docker-image.sh
    └── install.sh
```

- `.circleci/config.yml`: CircleCI pipeline configuration for building and deploying dockerized applications.
- `scripts`: Helper bash scripts used to drive the CI / CD pipeline.
    - `constants.sh`: Environment variables that are shared across all the scripts
    - `install.sh`: Installer script to configure the CI runtime with necessary dependencies for running the deployment
      scripts.
    - `build-docker-image.sh`: Script used by the CI runtime to build a new docker image for the application.
    - `deploy-docker-image.sh`: Script used by the CI runtime to deploy a prebuilt docker image for the application.

This sample pipeline configures the following workflow:

- For any commit on any branch, build a new docker image using the commit SHA.
- For commits to `main`, deploy the built image to the dev environment by updating the `infrastructure-live`
  configuration for the `dev` environment.
- For release tags, deploy the built image to the stage environment by updating the `infrastructure-live` configuration
  for the `stage` environment.

In this guide, we will walk through how to setup the CI / CD pipeline for your application code.

1. [Dockerize your app](#dockerize-your-app)
1. [Create infrastructure code to deploy your app](#create-infrastructure-code-to-deploy-your-app)
1. [Enable access to your application repo from ECS deploy
   runner](#enable-access-to-your-application-repo-from-ecs-deploy-runner)
1. [Install CI / CD Configuration](#install-ci-cd-configuration)
1. [Create CircleCI Job](#create-circleci-job)


### Dockerize your app

To deploy your app on ECS or EKS, you will first need to dockerize it. If you are not familiar with the basics of
docker, check out our "Crash Course on Docker and Packer" from the [Gruntwork Training
Library](https://training.gruntwork.io/p/a-crash-course-on-docker-packer).

**Once your app is dockerized, make note of the path from the root of your application repo to the `Dockerfile`.** This value will be used in your `_ci/scripts/constants.sh` as `DOCKER_CONTEXT_PATH`.


### Create infrastructure code to deploy your app

If you've already followed the previous guide [How to deploy your apps into the Reference
Architecture](03-deploy-apps.md), you should already have your module defined in the `infrastructure-live` repository
to deploy the app.

**Make note of the path from the account folder to the service configuration.** An example path is `"dev/us-east-1/dev/services/application`. These values will be used your `.circleci/config.yml` for `DEV_DEPLOY_PATH` and `STAGE_DEPLOY_PATH`.


### Enable access to your application repo from ECS deploy runner

Now you need to explicitly enable the ECS deploy runner to access your application repo.

Because the ECS deploy runner has defacto _admin_ credentials to your AWS accounts, it is locked down so that users
cannot deploy arbitrary code into your environments.

To allow the ECS deploy runner to start building and deploying your application:

1. Open this file for editing: `shared/us-west-2/mgmt/ecs-deploy-runner/terragrunt.hcl`.
1. Update `docker_image_builder_config.allowed_repos` to include the HTTPS Git URL of the application repo.
1. Save and commit the change.
1. Deploy the change using `terragrunt apply`.


### Install CI / CD Configuration

To declare a build job in CircleCI, the application repository needs a `.circleci/config.yml` file that records the steps that
CircleCI needs to run to deploy the app. To setup your repo with a CircleCI configuration that is compatible with
Gruntwork Pipelines:

1. In your application repository, checkout a new branch: `git checkout -B circleci`
1. Copy the template files from _this_ repo to your application repo:
    - `cp -r <THIS_REPO_ROOT>/_ci/app-templates/.circleci .circleci` to copy the CircleCI config folder.
    - `mkdir _ci` to create a new folder `_ci` in your application repository root.
    - `cp -r <THIS_REPO_ROOT>/_ci/app-templates/scripts _ci` to copy scripts into the new `_ci` folder.

1. Edit `.circleci/config.yml` to fill in the environment variables at the top, especially `REGION`, `DEV_DEPLOY_PATH`,
and `STAGE_DEPLOY_PATH`.
1. Edit `_ci/scripts/constants.sh` to fill in the environment variables at the top. The `DOCKER_CONTEXT_PATH` from earlier will also go here.
1. Commit and push:

        git add .circleci
        git add _ci
        git commit
        git push -u circleci

1. Open a PR on GitHub for your branch so it can be reviewed.

Once the branch is merged, updates to the `main` branch will trigger a build job in CircleCI.


### Create CircleCI Job

Configure CircleCI to watch the repo for changes:

1. Login to CircleCI.
1. Switch to the GitHub organization that has the application repository using the left panel.

   ![CircleCI Switch Organizations](images/circleci-setup/circleci_switch_orgs.gif)

1. Switch to the Projects tab using the left panel.
1. Search for your application repository and click **Set Up Project.**
1. Click **Start Building**.
1. In the build page, go to **Project Settings** (the upper right button, above **Auto-expand**).
1. In the settings page, go to **Environment Variables**. Configure the following environment variables:
    - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` : Use the AWS access key pair for the machine user that Gruntwork
      provided to you when the Reference Architecture was first set up.
    - `GITHUB_OAUTH_TOKEN` : Use the GitHub Personal Access Token for the GitHub machine user that you provided to
      Gruntwork.


## Next steps

Now that your code is built, tested, and deployed, it's time to take a look at [Monitoring, Alerting, and
Logging](05-monitoring-alerting-logging.md).
