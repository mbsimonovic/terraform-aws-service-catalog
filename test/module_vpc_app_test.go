package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcApp(t *testing.T) {
	t.Parallel()

	awsRegion := aws.GetRandomRegion(t, regionsForEc2Tests, nil)

	testFolder := "../examples/for-learning-and-testing/networking/vpc-app"
	terraformOptions := createBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["vpc_name"] = "vpc-test-" + random.UniqueId()
	terraformOptions.Vars["cidr_block"] = "10.100.0.0/18"
	terraformOptions.Vars["num_nat_gateways"] = "1"

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vpc_id := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Regexp(t, "^vpc-.*", vpc_id)

	public_subnet_ids := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Regexp(t, "^subnet-.*", public_subnet_ids[0])
}
