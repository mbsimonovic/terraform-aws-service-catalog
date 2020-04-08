package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestK8SService(t *testing.T) {
	t.Parallel()

	testFolder := "../examples/for-learning-and-testing/services/k8s-service"

	uniqueID := random.UniqueId()
	applicationName := fmt.Sprintf("nginx-%s", strings.ToLower(uniqueID))
	terraformOptions := createBaseTerraformOptions(t, testFolder, "us-west-2")
	terraformOptions.Vars["application_name"] = applicationName
	terraformOptions.Vars["image"] = "nginx"
	terraformOptions.Vars["image_version"] = "1.17"
	terraformOptions.Vars["container_port"] = 80

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	options := k8s.NewKubectlOptions("", "", "default")
	verifyPodsCreatedSuccessfully(t, options, applicationName)
	verifyAllPodsAvailable(t, options, applicationName, nginxValidationFunction)
	verifyServiceAvailable(t, options, applicationName)
}
