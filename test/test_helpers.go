package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/shell"
	"os"
	"sync"
	"testing"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

const (
	MaxTerraformRetries          = 3
	SleepBetweenTerraformRetries = 5 * time.Second
)

var (
	// Set up terratest to retry on known failures
	RetryableTerraformErrors = map[string]string{
		// `terraform init` frequently fails in CI due to network issues accessing plugins. The reason is unknown, but
		// eventually these succeed after a few retries.
		".*unable to verify signature.*":                "Failed to retrieve plugin due to transient network error.",
		".*unable to verify checksum.*":                 "Failed to retrieve plugin due to transient network error.",
		".*no provider exists with the given name.*":    "Failed to retrieve plugin due to transient network error.",
		".*registry service is unreachable.*":           "Failed to retrieve plugin due to transient network error.",
		".*timeout while waiting for plugin to start.*": "Failed to retrieve plugin due to transient network error.",
		".*timed out waiting for server handshake.*":    "Failed to retrieve plugin due to transient network error.",

		// Based on the full error message: "module.vpc_app_example.aws_vpc_endpoint_route_table_association.s3_private[0], provider "registry.terraform.io/hashicorp/aws" produced an unexpected new value: Root resource was present, but now absent."
		// See https://github.com/hashicorp/terraform-provider-aws/issues/12449 and https://github.com/hashicorp/terraform-provider-aws/issues/12829
		"Root resource was present, but now absent": "This seems to be an eventual consistency issue with AWS where Terraform looks for a route table association that was just created but doesn't yet see it: https://github.com/hashicorp/terraform-provider-aws/issues/12449",
	}
)

// Test constants for the Gruntwork Phx DevOps account
const (
	BaseDomainForTest = "gruntwork.in"
	AcmDomainForTest  = "*.gruntwork.in"
)

// Regions in Gruntwork Phx DevOps account that have ACM certs and t3.micro instances in all AZs
var RegionsForEc2Tests = []string{
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"ap-northeast-1",
	"ap-southeast-2",
}

// Tags in Gruntwork Phx DevOps account to uniquely find Hosted Zone for BaseDomainForTest
var DomainNameTagsForTest = map[string]interface{}{"original": "true"}

// Some of the tests need to run against Organization root account. This method overrides the default AWS_* environment variables
func ConfigureTerraformForOrgTestAccount(t *testing.T, terraformOptions *terraform.Options) {
	if terraformOptions.EnvVars == nil {
		terraformOptions.EnvVars = map[string]string{}
	}
	terraformOptions.EnvVars["AWS_ACCESS_KEY_ID"] = os.Getenv("AWS_ORGTEST_ACCESS_KEY_ID")
	terraformOptions.EnvVars["AWS_SECRET_ACCESS_KEY"] = os.Getenv("AWS_ORGTEST_SECRET_ACCESS_KEY")
}

func PickNRegions(t *testing.T, count int) []string {
	regions := []string{}
	for i := 0; i < count; i++ {
		region := aws.GetRandomStableRegion(t, nil, regions)
		regions = append(regions, region)
	}
	return regions
}

// read the externalAccountId to use for saving RDS snapshots from the environment
func GetExternalAccountId() string {
	return os.Getenv("TEST_EXTERNAL_ACCOUNT_ID")
}

func PickAwsRegion(t *testing.T) string {
	// At least one zone in us-west-2, sa-east-1, eu-north-1, ap-northeast-2 do not have t2.micro
	// ap-south-1 doesn't have ECS optimized Linux
	return aws.GetRandomStableRegion(t, []string{}, []string{"sa-east-1", "ap-south-1", "ap-northeast-2", "us-west-2", "eu-north-1"})
}

func CreateBaseTerraformOptions(t *testing.T, terraformDir string, awsRegion string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"aws_region": awsRegion,
		},
		RetryableTerraformErrors: RetryableTerraformErrors,
		MaxRetries:               MaxTerraformRetries,
		TimeBetweenRetries:       SleepBetweenTerraformRetries,
	}
}

func TestSSH(t *testing.T, ip string, sshUsername string, keyPair *aws.Ec2Keypair) {
	publicHost := ssh.Host{
		Hostname:    ip,
		SshUserName: sshUsername,
		SshKeyPair:  keyPair.KeyPair,
	}

	retry.DoWithRetry(
		t,
		fmt.Sprintf("SSH to public host %s", ip),
		10,
		30*time.Second,
		func() (string, error) {
			return "", ssh.CheckSshConnectionE(t, publicHost)
		},
	)
}

func TestSSHCommand(t *testing.T, ip string, sshUsername string, keyPair *aws.Ec2Keypair, command string) string {
	publicHost := ssh.Host{
		Hostname:    ip,
		SshUserName: sshUsername,
		SshKeyPair:  keyPair.KeyPair,
	}

	return retry.DoWithRetry(
		t,
		fmt.Sprintf("SSH to public host %s", ip),
		10,
		30*time.Second,
		func() (string, error) {
			return ssh.CheckSshCommandE(t, publicHost, command)
		},
	)
}

func RequireEnvVar(t *testing.T, envVarName string) {
	require.NotEmptyf(t, os.Getenv(envVarName), "Environment variable %s must be set for this test.", envVarName)
}

// PlanWithParallelismE runs terraform plan with the given options including the parallelism flag and returns stdout/stderr.
// This will fail the test if there is an error in the command.
func PlanWithParallelismE(t *testing.T, options *terraform.Options) (string, error) {
	return terraform.RunTerraformCommandE(t, options, terraform.FormatArgs(options, "plan", "-parallelism=2", "-input=false", "-lock=false")...)
}

var ecrAuthMutex sync.Mutex

// Authenticate to ECR in the given region and run the given command.
func RunCommandWithEcrAuth(t *testing.T, command string, awsRegion string) string {
	// We've seen issues where multiple tests doing 'docker login' concurrently leads to conflicts, so we use a lock
	// to ensure they don't do it simultaneously.
	defer ecrAuthMutex.Unlock()
	ecrAuthMutex.Lock()

	cmd := shell.Command{
		Command: "bash",
		Args: []string{
			"-c",
			fmt.Sprintf(
				"eval $(aws ecr get-login --no-include-email --region %s) && %s",
				awsRegion,
				command,
			),
		},
	}
	return shell.RunCommandAndGetOutput(t, cmd)
}