package test

import (
	"github.com/stretchr/testify/assert"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestMockAsgService(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/for-learning-and-testing/services/mock-asg-service",
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	instance_ip := terraform.Output(t, terraformOptions, "instance_ip")
	assert.Regexp(t, "\\d{0,4}\\.\\d{0,4}\\.\\d{0,4}\\.\\d{0,4}", instance_ip)

	service_url := terraform.Output(t, terraformOptions, "service_url")
	assert.Regexp(t, "^http://ami-.*", service_url)
}