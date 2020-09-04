package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"testing"
)

func TestGruntworkAccess(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/for-learning-and-testing/landingzone/gruntwork-access",
		Vars: map[string]interface{}{
			"aws_region":    aws.GetRandomStableRegion(t, nil, nil),
			"iam_role_name": fmt.Sprintf("GruntworkAccountAccessRole-%s", random.UniqueId()),
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
