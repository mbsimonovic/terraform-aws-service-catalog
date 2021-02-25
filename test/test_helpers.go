package test

import (
	"database/sql"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
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

type RDSInfo struct {
	Username   string
	Password   string
	DBName     string
	DBEndpoint string
	DBPort     string
}

// SmokeTestMysql makes a "SELECT 1+1" query over the mysql protocol to the provided RDS database.
func SmokeTestMysql(t *testing.T, serverInfo RDSInfo) {
	result := retry.DoWithRetry(
		t,
		"connect to mysql",
		// Try 10 times, 30 seconds apart. The most common failure here is an out of memory issue, so when we run into
		// it, we want to space out the calls so that they don't overlap with other terraform calls happening.
		10,
		30*time.Second,
		func() (string, error) {
			dbConnString := fmt.Sprintf(
				"%s:%s@tcp(%s:%s)/%s",
				serverInfo.Username,
				serverInfo.Password,
				serverInfo.DBEndpoint,
				serverInfo.DBPort,
				serverInfo.DBName,
			)
			db, connErr := sql.Open("mysql", dbConnString)
			if connErr != nil {
				return "", connErr
			}
			defer db.Close()

			row := db.QueryRow("SELECT 1+1;")
			var result string
			scanErr := row.Scan(&result)
			if scanErr != nil {
				return "", scanErr
			}
			return result, nil
		},
	)
	assert.Equal(t, "2", result)
}

func SmokeTestMysqlWithKubernetes(t *testing.T, kubectlOptions *k8s.KubectlOptions, serverInfo RDSInfo) {
	defer k8s.RunKubectl(t, kubectlOptions, "delete", "pod", "mysql")
	k8s.RunKubectl(t, kubectlOptions, "run", "--generator=run-pod/v1", "--image", "mysql", "mysql", "--", "sleep", "9999999")

	kubectlExecMysqlCommand := []string{
		"exec", "mysql", "--", "mysql",
		"-h", serverInfo.DBEndpoint,
		"-u", serverInfo.Username,
		fmt.Sprintf("--password=%s", serverInfo.Password),
		"-P", serverInfo.DBPort,
		"--ssl-mode", "DISABLED",
		"-e", "SELECT 1+1;",
	}
	out := retry.DoWithRetry(
		t,
		"try mysql connection",
		10,
		5*time.Second,
		func() (string, error) {
			return k8s.RunKubectlAndGetOutputE(t, kubectlOptions, kubectlExecMysqlCommand...)
		},
	)
	resp := strings.Split(out, "\n")
	assert.Equal(t, resp[len(resp)-1], "2")
}

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
