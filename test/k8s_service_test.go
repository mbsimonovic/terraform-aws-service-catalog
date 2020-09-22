package test

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

var k8sServiceTestCases = []struct {
	name          string
	extraVarsFunc func(*testing.T, *k8s.KubectlOptions) map[string]interface{}
	greetingFunc  func(string) string
}{
	{
		"Default",
		noExtraVarsForK8SService,
		func(string) string { return "Hello from the dev config!" },
	},
	{
		"WithConfigMap",
		extraVarsForK8SServiceFromConfigMap,
		getCustomGreeting,
	},
	{
		"WithSecret",
		extraVarsForK8SServiceFromSecret,
		getCustomGreeting,
	},
}

// This test spawns three tests against k8s-service:
// - No extra env vars
// - With ConfigMap based env vars
// - With Secrets based env vars
func TestK8SService(t *testing.T) {
	t.Parallel()

	// Uncomment any of the following to skip that section during the test
	//os.Setenv("SKIP_create_namespace", "true")
	//os.Setenv("SKIP_deploy", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_destroy", "true")
	//os.Setenv("SKIP_delete_namespace", "true")

	for _, testCase := range k8sServiceTestCases {
		// Capture range variable to within for block scope so that it doesn't change as we switch go routines with the
		// t.Parallel calls.
		testCase := testCase

		// Set a custom dir for stage data that won't overlap across the tests
		workingDir := filepath.Join(".", "stages", t.Name())

		// We don't need to wrap the subtests in a group here because we don't have any shared cleanup function, so there is
		// no need to wait for all the tests to run before exiting this function. So we spawn all the tests directly.
		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			testFolder := test_structure.CopyTerraformFolderToTemp(
				t,
				"..",
				"examples/for-learning-and-testing/services/k8s-service",
			)
			applicationName := "sampleapp"
			rootOptions := k8s.NewKubectlOptions("", "", "")

			defer test_structure.RunTestStage(t, "delete_namespace", func() {
				namespaceOptions := test_structure.LoadKubectlOptions(t, workingDir)
				k8s.DeleteNamespace(t, rootOptions, namespaceOptions.Namespace)
			})
			test_structure.RunTestStage(t, "create_namespace", func() {
				namespace := strings.ToLower(random.UniqueId())
				k8s.CreateNamespace(t, rootOptions, namespace)
				namespaceOptions := k8s.NewKubectlOptions("", "", namespace)
				test_structure.SaveKubectlOptions(t, workingDir, namespaceOptions)
			})

			defer test_structure.RunTestStage(t, "destroy", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
				terraform.Destroy(t, terraformOptions)
			})
			test_structure.RunTestStage(t, "deploy", func() {
				namespaceOptions := test_structure.LoadKubectlOptions(t, workingDir)

				terraformOptions := createBaseTerraformOptions(t, testFolder, "us-west-2")
				terraformOptions.Vars["application_name"] = applicationName
				terraformOptions.Vars["namespace"] = namespaceOptions.Namespace
				for key, val := range testCase.extraVarsFunc(t, namespaceOptions) {
					terraformOptions.Vars[key] = val
				}
				test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)

				terraform.InitAndApply(t, terraformOptions)
			})

			test_structure.RunTestStage(t, "validate", func() {
				namespaceOptions := test_structure.LoadKubectlOptions(t, workingDir)
				expectedGreeting := testCase.greetingFunc(namespaceOptions.Namespace)
				verifyPodsCreatedSuccessfully(t, namespaceOptions, applicationName)
				verifyAllPodsAvailable(t, namespaceOptions, applicationName, "/greeting", sampleAppValidationWithGreetingFunctionGenerator(expectedGreeting))
				verifyServiceAvailable(t, namespaceOptions, applicationName)
			})
		})
	}
}

// Create a custom configmap to set a custom greeting and return terraform variable settings that configure the
// k8s-service module to source the greeting from the custom configmap we created.
func extraVarsForK8SServiceFromConfigMap(t *testing.T, kubectlOptions *k8s.KubectlOptions) map[string]interface{} {
	k8s.RunKubectl(t, kubectlOptions, "create", "configmap", "greeting", fmt.Sprintf("--from-literal=greeting=%s", getCustomGreeting(kubectlOptions.Namespace)))
	return map[string]interface{}{
		"configmaps_as_env_vars": map[string]interface{}{
			"greeting": map[string]interface{}{
				"greeting": "CONFIG_APP_GREETING",
			},
		},
	}
}

// Create a custom secret to set a custom greeting and return terraform variable settings that configure the
// k8s-service module to source the greeting from the custom secret we created.
func extraVarsForK8SServiceFromSecret(t *testing.T, kubectlOptions *k8s.KubectlOptions) map[string]interface{} {
	k8s.RunKubectl(t, kubectlOptions, "create", "secret", "generic", "greeting", fmt.Sprintf("--from-literal=greeting=%s", getCustomGreeting(kubectlOptions.Namespace)))
	return map[string]interface{}{
		"secrets_as_env_vars": map[string]interface{}{
			"greeting": map[string]interface{}{
				"greeting": "CONFIG_APP_GREETING",
			},
		},
	}
}

// Return no extra vars. Used as a noop for test routine.
func noExtraVarsForK8SService(t *testing.T, kubectlOptions *k8s.KubectlOptions) map[string]interface{} {
	return map[string]interface{}{}
}

// sampleAppValidationWithGreetingFunction checks that we get a 200 response with the configured sample app greeting
// message.
func sampleAppValidationWithGreetingFunctionGenerator(expectedGreeting string) func(statusCode int, body string) bool {
	return func(statusCode int, body string) bool {
		return statusCode == 200 && strings.Contains(body, expectedGreeting)
	}
}

func getCustomGreeting(namespace string) string {
	return fmt.Sprintf("Hello from namespace %s", namespace)
}
