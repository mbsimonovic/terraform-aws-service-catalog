package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMockVpc(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "../modules/mock-vpc",
		Vars: map[string]interface{}{
			"vpc_name": "vpc-test",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vpc_id := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Regexp(t, "^vpc-.*", vpc_id)
}