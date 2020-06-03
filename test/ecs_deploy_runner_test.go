package test

import (
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const repo = "git@github.com:gruntwork-io/aws-service-catalog.git"

// TestEcsDeployRunner tests the ECS Deploy Runner module.
// Since certain parts of the pipeline take a long time, this test is broken up into
// multiple sub tests to support setup and cleanup functionalities. The hierarchy is as follows:
//
// TestDeployRunnerECSTaskDeployment
// └── subgroup
//     └── ... additional sub tests ...
//
// TestDeployRunnerECSTaskDeployment will setup the docker image and ECR repository.
//
// The environment variable TERRATEST_SSH_PRIVATE_KEY_PATH must be set to a valid path containing an SSH private key
// that can be used to clone Gruntwork Repos.
func TestEcsDeployRunner(t *testing.T) {
	t.Parallel()

	// Setup
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_setup_ecr_repo", "true")
	//os.Setenv("SKIP_setup_ssh_private_key", "true")
	//os.Setenv("SKIP_build_docker_image", "true")
	//os.Setenv("SKIP_push_docker_image", "true")

	// Refer to top of testDeploymentScenarios additional skips

	// Cleanup
	//os.Setenv("SKIP_delete_docker_image", "true")
	//os.Setenv("SKIP_cleanup_ssh_private_key", "true")
	//os.Setenv("SKIP_cleanup_ecr_repo", "true")

	// Create a directory path that won't conflict
	workingDir := filepath.Join(".", "stages", t.Name())

	// Setup test environment by choosing a region and generating a unique ID for namespacing resources.
	test_structure.RunTestStage(t, "setup", func() {
		region := aws.GetRandomStableRegion(t, ECSFargateRegions, nil)
		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, workingDir, "UniqueID", uniqueID)
		test_structure.SaveString(t, workingDir, "AwsRegion", region)
	})
	uniqueID := test_structure.LoadString(t, workingDir, "UniqueID")
	region := test_structure.LoadString(t, workingDir, "AwsRegion")
	repository := fmt.Sprintf("gruntwork/ecs-deploy-runner-%s", uniqueID)

	// Setup ECR repository
	defer test_structure.RunTestStage(t, "cleanup_ecr_repo", func() {
		deleteECRRepo(t, region, repository)
	})
	test_structure.RunTestStage(t, "setup_ecr_repo", func() {
		repositoryUri := createECRRepo(t, region, repository)
		test_structure.SaveString(t, workingDir, "EcrRepositoryUri", repositoryUri)
	})
	repositoryUri := test_structure.LoadString(t, workingDir, "EcrRepositoryUri")
	imgTag := fmt.Sprintf("%s:v1", repositoryUri)

	// Setup private ssh key in secrets manager
	defer test_structure.RunTestStage(t, "cleanup_ssh_private_key", func() {
		secretsManagerArn := test_structure.LoadString(t, workingDir, "SSHKeySecretsManagerArn")
		deleteSSHKeySecret(t, region, secretsManagerArn)
	})
	test_structure.RunTestStage(t, "setup_ssh_private_key", func() {
		secretsManagerArn := loadSSHKeyToSecretsManager(t, region, uniqueID)
		test_structure.SaveString(t, workingDir, "SSHKeySecretsManagerArn", secretsManagerArn)
	})
	secretsManagerArn := test_structure.LoadString(t, workingDir, "SSHKeySecretsManagerArn")

	// Build and push docker image
	defer test_structure.RunTestStage(t, "delete_docker_image", func() {
		deleteDockerImage(t, imgTag)
	})
	test_structure.RunTestStage(t, "build_docker_image", func() {
		buildOpts := &docker.BuildOptions{
			Tags:         []string{imgTag},
			BuildArgs:    []string{"GITHUB_OAUTH_TOKEN"},
			OtherOptions: []string{"--no-cache"},
		}
		docker.Build(t, "../examples/for-learning-and-testing/mgmt/ecs-deploy-runner/docker", buildOpts)
	})
	test_structure.RunTestStage(t, "push_docker_image", func() {
		pushCmd := shell.Command{
			Command: "bash",
			Args: []string{
				"-c",
				fmt.Sprintf(
					"eval $(aws ecr get-login --no-include-email --region %s) && docker push %s",
					region,
					imgTag,
				),
			},
		}
		shell.RunCommand(t, pushCmd)
	})

	testDeploymentScenarios(t, uniqueID, region, secretsManagerArn, repositoryUri)
}

// Test that the deploy runner ECS task can be invoked and works as expected.
func testDeploymentScenarios(
	t *testing.T,
	parentUniqueID string,
	region string,
	secretsManagerArn string,
	repositoryUri string,
) {
	// Setup code
	//os.Setenv("SKIP_setup_deployment_test", "true")
	//os.Setenv("SKIP_apply_deploy_runner", "true")

	// Clean up code
	//os.Setenv("SKIP_destroy_deploy_runner", "true")

	// Create a directory path that won't conflict
	workingDir := filepath.Join(".", "stages", t.Name())

	test_structure.RunTestStage(t, "setup_deployment_test", func() {
		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, workingDir, "UniqueID", uniqueID)
	})
	uniqueID := test_structure.LoadString(t, workingDir, "UniqueID")
	name := fmt.Sprintf("%s-ecs-deploy-runner-%s", parentUniqueID, uniqueID)
	modulePath := test_structure.CopyTerraformFolderToTemp(t, "..", "examples/for-learning-and-testing/mgmt/ecs-deploy-runner")

	// Deploy the ECS deploy runner
	deployOpts := &terraform.Options{
		TerraformDir: modulePath,
		Vars: map[string]interface{}{
			"aws_region": region,
			"name":       name,
			"container_image": map[string]string{
				"repo": repositoryUri,
				"tag":  "v1",
			},
			"repository":                          repo,
			"approved_apply_refs":                 []string{"master"},
			"ssh_private_key_secrets_manager_arn": secretsManagerArn,
		},
	}
	defer test_structure.RunTestStage(t, "destroy_deploy_runner", func() {
		terraform.Destroy(t, deployOpts)
	})
	test_structure.RunTestStage(t, "apply_deploy_runner", func() {
		terraform.InitAndApply(t, deployOpts)
	})
}
