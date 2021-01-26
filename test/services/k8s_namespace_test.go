package services

import (
	"fmt"
	"github.com/gruntwork-io/aws-service-catalog/test"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestK8SNamespace(t *testing.T) {
	t.Parallel()

	testFolder := "../examples/for-learning-and-testing/services/k8s-namespace"

	uniqueID := random.UniqueId()
	namespaceName := fmt.Sprintf("applications-%s", strings.ToLower(uniqueID))
	terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, "")
	terraformOptions.Vars["name"] = namespaceName

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	options := k8s.NewKubectlOptions("", "", namespaceName)

	// If this returns without error, then the namespace exists
	k8s.GetNamespace(t, options, namespaceName)
}
