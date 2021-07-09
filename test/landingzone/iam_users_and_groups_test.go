package landingzone

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestIamUsersAndGroups(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../examples/for-learning-and-testing/landingzone/iam-users-and-groups",
		Vars: map[string]interface{}{
			"aws_region":  aws.GetRandomStableRegion(t, nil, nil),
			"name_prefix": fmt.Sprintf("%s", strings.ToLower(random.UniqueId())),
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
