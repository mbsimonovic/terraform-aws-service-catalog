package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcApp(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/for-learning-and-testing/networking/vpc-app",
		Vars: map[string]interface{}{
			"vpc_name": "vpc-test",
			"aws_account_id": "123",
			"aws_region": "us-east-1",
			"cidr_block": "10.100.0.0/18",
			"num_nat_gateways": "1",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vpc_id := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Regexp(t, "^vpc-.*", vpc_id)

	public_subnet_ids := terraform.Output(t, terraformOptions, "public_subnet_ids")
	assert.Regexp(t, ".*subnet-.*", public_subnet_ids)
}

