## How do you deploy this example?

First, make sure that you have these tools installed:

1. [Docker](https://www.docker.com/).
1. [Terraform](https://www.terraform.io/).

Next, build the lambda deployment package:

1. `./python/build.sh`

Next, deploy the code with Terraform:

1. Open `variables.tf` and change the variables that you want.
1. Run `terraform init`.
1. Run `terraform plan -out plan`.
1. If the plan looks good, run `terraform apply plan`.

## How do you test the Lambda function?

There are two ways to test the Lambda function once it's deployed:

1. [Test in AWS](#test-in-aws)
1. [Test locally](#test-locally)


### Test in AWS

Open up the [AWS Console UI](https://console.aws.amazon.com/lambda/home), find the function, click the "Test" button,
and enter test data that looks something like this:

```json
{
  "url": "http://www.example.com"
}
```

Click "Save and test" and AWS will show you the log output and returned value in the browser.


### Test locally

The code you write for a Lambda function is just regular code with a well-defined entrypoint (the "handler"), so you can also run it locally by calling that entrypoint. The example Python app includes a `test_harness.py` file that is configured to allow you to run your code locally. This test harness script is configured as the `ENTRYPOINT` for the Docker container, so you can test locally as follows:

```bash
cd python
docker build -t gruntwork/lambda-build-example .
docker run -it --rm gruntwork/lambda-build-example http://www.example.com
```

To avoid having to do a `docker build` every time, you can do all subsequent `docker run` calls with your local `src`
folder mounted as a volume so that the Docker container always sees your latest source code:

```bash
docker run -it --rm -v ${PWD}/src:/usr/src/lambda/src gruntwork/lambda-build-example http://www.example.com
```
