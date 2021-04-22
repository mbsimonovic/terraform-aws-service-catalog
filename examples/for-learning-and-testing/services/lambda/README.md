# Lambda Example

This is an example of how to use the [Lambda module](/modules/services/lambda)
to create a Lambda function.
This example is optimized for learning, experimenting, and testing (but not
direct production usage). If you want to deploy modules directly in production,
check out the [examples/for-production folder](/examples/for-production).

## Deploy Instructions

1. Install [Python 3](https://www.python.org).
1. Install [Docker](https://www.docker.com/).
1. Install [Terraform](https://www.terraform.io/).
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any
   others you wish to override). We recommend setting these variables in a
   `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables)
   for all the ways you can set Terraform variables).
1. Build the lambda deployment package with `./python/build.sh`.
1. Run `terraform init`.
1. Run `terraform apply`.
1. The module will output the endpoint of the lambda function.  <!-- Validate/update the output -->
1. When you're done testing, to undeploy everything, run `terraform destroy`.

## Testing the Lambda

There are two ways to test the Lambda function once it's deployed:

1. [Test in AWS](#test-in-aws)
1. [Test locally](#test-locally)

### Test in AWS

After the lambda deployment, open up the [AWS Console UI](https://console.aws.amazon.com/lambda/home),
find the function, click the "Test" button, and enter test data that looks something like this:

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
