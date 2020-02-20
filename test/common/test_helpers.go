package testcommon

import (
	"testing"
	"time"

	terraws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
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
		".*unable to verify signature.*":             "Failed to retrieve plugin due to transient network error.",
		".*unable to verify checksum.*":              "Failed to retrieve plugin due to transient network error.",
		".*no provider exists with the given name.*": "Failed to retrieve plugin due to transient network error.",
		".*registry service is unreachable.*":        "Failed to retrieve plugin due to transient network error.",
	}
)

func PickAwsRegion(t *testing.T) string {
	// At least one zone in us-west-2, sa-east-1, eu-north-1, ap-northeast-2 do not have t2.micro
	// ap-south-1 doesn't have ECS optimized Linux
	return terraws.GetRandomStableRegion(t, []string{}, []string{"sa-east-1", "ap-south-1", "ap-northeast-2", "us-west-2", "eu-north-1"})
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
