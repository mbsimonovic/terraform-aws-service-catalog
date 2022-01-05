package test

import (
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// The following comment exists to force a full test suite build when terraform, terragrunt, and packer versions are
// updated.
// renovate.json auto-update-github-releases: hashicorp/terraform
// Test TF Version: 1.0.10
// renovate.json auto-update: terragrunt
// Test TG Version: v0.35.16
// renovate.json auto-update: terratest
// Test TT Version: v0.38.8
// renovate.json auto-update-github-releases: hashicorp/packer
// Test PCK Version: 1.7.8

// Retry configuration constants
const (
	maxTerraformRetries          = 3
	sleepBetweenTerraformRetries = 5 * time.Second
)

var retryableTerraformErrors = map[string]string{
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

	// Based on the full error message: "error reading Route Table Association (rtbassoc-0debe83161f2691ec): Empty
	// result"
	"error reading.*[Ee]mpty result":        "This seems to be an eventual consistency issue with AWS where Terraform looks for a route table association that was just created but doesn't yet see it: https://github.com/hashicorp/terraform-provider-aws/issues/12449",
	"error reading.*couldn't find resource": "This seems to be an eventual consistency issue with AWS where Terraform looks for a route table association that was just created but doesn't yet see it: https://github.com/hashicorp/terraform-provider-aws/issues/12449",

	// Based on the full error message: "error waiting for Route Table Association (rtbassoc-0c83c992303e0797f)
	// delete: unexpected state 'associated', wanted target ''"
	"error waiting for Route Table Association.*delete: unexpected state": "This seems to be an eventual consistency issue with AWS where Terraform looks for a route table association that was just created but doesn't yet see it: https://github.com/hashicorp/terraform-provider-aws/issues/12449",
}

// Domain constants
const (
	BaseDomainForTest = "gruntwork.in"
	AcmDomainForTest  = "*.gruntwork.in"
)

// Tags in Gruntwork Phx DevOps account to uniquely find Hosted Zone for BaseDomainForTest
var DomainNameTagsForTest = map[string]interface{}{"original": "true"}

// Regions in Gruntwork Phx DevOps account that have ACM certs and t3.micro instances in all AZs
var RegionsForEc2Tests = []string{
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"ap-northeast-1",
	"ap-southeast-2",
}

// read the externalAccountId to use for saving RDS snapshots from the environment
func GetExternalAccountId() string {
	return os.Getenv("TEST_EXTERNAL_ACCOUNT_ID")
}

func CreateBaseTerraformOptions(t *testing.T, terraformDir string, awsRegion string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"aws_region": awsRegion,
		},
		RetryableTerraformErrors: retryableTerraformErrors,
		MaxRetries:               maxTerraformRetries,
		TimeBetweenRetries:       sleepBetweenTerraformRetries,
	}
}

func RequireEnvVar(t *testing.T, envVarName string) {
	require.NotEmptyf(t, os.Getenv(envVarName), "Environment variable %s must be set for this test.", envVarName)
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
