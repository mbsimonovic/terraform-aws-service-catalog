package services

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/gruntwork-io/aws-service-catalog/test"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLambdaService(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_build_lambda", "true")
	// os.Setenv("SKIP_deploy_lambda", "true")
	// os.Setenv("SKIP_validate_lambda", "true")
	// os.Setenv("SKIP_cleanup", "true")
	// os.Setenv("SKIP_cleanup_lambda", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../..", "examples/for-learning-and-testing/services/lambda")

	awsRegion := aws.GetRandomRegion(t, nil, nil)
	name := fmt.Sprintf("lambda-%s", random.UniqueId())

	terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["name"] = name
	terraformOptions.TerraformDir = testFolder

	test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

	defer test_structure.RunTestStage(t, "cleanup_lambda", func() {
		cleanupLambdaArtifacts(t, terraformOptions)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "build_lambda", func() {
		buildLambdaArtifacts(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_lambda", func() {
		deployLambda(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_lambda", func() {
		validateLambda(t, terraformOptions)
	})
}

func cleanupLambdaArtifacts(t *testing.T, terraformOptions *terraform.Options) {
	command := shell.Command{
		Command: "rm",
		Args: []string{
			"-rf",
			"python/build/",
		},
		WorkingDir: terraformOptions.TerraformDir,
	}
	shell.RunCommand(t, command)
}

func buildLambdaArtifacts(t *testing.T, terraformOptions *terraform.Options) {
	command := shell.Command{
		Command:    "./python/build.sh",
		WorkingDir: terraformOptions.TerraformDir,
	}
	shell.RunCommand(t, command)
}

func deployLambda(t *testing.T, terraformOptions *terraform.Options) {
	terraform.InitAndApply(t, terraformOptions)
}

type Response struct {
	Status int
}

func validateLambda(t *testing.T, terraformOptions *terraform.Options) {
	awsRegion := terraformOptions.Vars["aws_region"].(string)
	name := terraformOptions.Vars["name"].(string)

	payload := map[string]string{
		"url": "http://www.example.com",
	}

	out, err := aws.InvokeFunctionE(t, awsRegion, name, payload)
	require.NoError(t, err)

	var response Response
	err = json.Unmarshal([]byte(out), &response)
	require.NoError(t, err)

	assert.Equal(t, 200, response.Status)
}
