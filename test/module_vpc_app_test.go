package test

import (
	"github.com/gruntwork-io/terratest/modules/aws"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
)

func TestVpcApp(t *testing.T) {
	t.Parallel()

	whitelistedRegionsForTest := []string{"us-east-1", "us-east-1", "us-west-1", "us-west-2", "eu-central-1"}
	awsRegion := aws.GetRandomRegion(t, whitelistedRegionsForTest, nil)

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/for-learning-and-testing/networking/vpc-app",
		Vars: map[string]interface{}{
			"vpc_name": "vpc-test-" + random.UniqueId(),
			"aws_region": awsRegion,
			"cidr_block": "10.100.0.0/18",
			"num_nat_gateways": "1",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vpc_id := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Regexp(t, "^vpc-.*", vpc_id)

	public_subnet_ids := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Regexp(t, "^subnet-.*", public_subnet_ids[0])
}

