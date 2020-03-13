package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

func TestECRRepositories(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_build_and_push_docker_image", "true")
	//os.Setenv("SKIP_validate_image", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/ecr-repos")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, nil, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")

		name := fmt.Sprintf("sample-app-%s", strings.ToLower(uniqueID))
		test_structure.SaveString(t, testFolder, "repoName", name)

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"aws_region": awsRegion,
				"repositories": map[string]interface{}{
					name: map[string]interface{}{
						"external_account_ids_with_read_access":  []string{},
						"external_account_ids_with_write_access": []string{},
						"tags":                                   map[string]string{"Organization": "Gruntwork"},
						"enable_automatic_image_scanning":        true,
					},
				},
			},
		}
		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	name := test_structure.LoadString(t, testFolder, "repoName")
	awsRegion := test_structure.LoadString(t, testFolder, "region")
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	repoUrls := terraform.OutputMap(t, terraformOptions, "ecr_repo_urls")
	repoUrl := repoUrls[name]
	imgTag := fmt.Sprintf("%s:v1", repoUrl)

	// Build and push docker image
	test_structure.RunTestStage(t, "build_and_push_docker_image", func() {
		// Delete image immediately, as we want to test pulling from ECR
		defer func() {
			cmd := shell.Command{
				Command: "docker",
				Args:    []string{"rmi", imgTag},
			}
			shell.RunCommand(t, cmd)
		}()

		buildOpts := &docker.BuildOptions{
			Tags:         []string{imgTag},
			OtherOptions: []string{"--no-cache"},
		}
		docker.Build(t, "./fixtures/simple-docker-img", buildOpts)

		pushCmd := shell.Command{
			Command: "bash",
			Args: []string{
				"-c",
				fmt.Sprintf(
					"eval $(aws ecr get-login --no-include-email --region %s) && docker push %s",
					awsRegion,
					imgTag,
				),
			},
		}
		shell.RunCommand(t, pushCmd)
	})

	// Validate the image in ECR by pulling it down and running it.
	test_structure.RunTestStage(t, "validate_image", func() {
		testCmd := shell.Command{
			Command: "bash",
			Args: []string{
				"-c",
				fmt.Sprintf(
					"eval $(aws ecr get-login --no-include-email --region %s) && docker run --rm %s",
					awsRegion,
					imgTag,
				),
			},
		}
		out := shell.RunCommandAndGetOutput(t, testCmd)
		assert.Contains(t, out, "Hello from Docker!")
	})
}
