package test

import (
	"fmt"
	"os"
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

const (
	serviceCatalogRepo = "git@github.com:gruntwork-io/aws-service-catalog.git"
	deployRunnerImgTag = "deploy-runner-v1"
	kanikoImgTag       = "kaniko-v1"

	moduleCIRepo = "git@github.com:gruntwork-io/module-ci.git"
	moduleCITag  = "v0.24.0"
)

// TestEcsDeployRunner tests the ECS Deploy Runner module.
// The environment variable TERRATEST_SSH_PRIVATE_KEY_PATH must be set to a valid path containing an SSH private key
// that can be used to clone Gruntwork Repos.
func TestEcsDeployRunner(t *testing.T) {
	t.Parallel()

	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_setup_ecr_repo", "true")
	//os.Setenv("SKIP_setup_ssh_private_key", "true")
	//os.Setenv("SKIP_build_docker_image", "true")
	//os.Setenv("SKIP_push_docker_image", "true")
	//os.Setenv("SKIP_apply_deploy_runner", "true")
	//os.Setenv("SKIP_destroy_deploy_runner", "true")
	//os.Setenv("SKIP_delete_docker_image", "true")
	//os.Setenv("SKIP_cleanup_ssh_private_key", "true")
	//os.Setenv("SKIP_cleanup_ecr_repo", "true")

	modulePath := test_structure.CopyTerraformFolderToTemp(t, "..", "examples/for-learning-and-testing/mgmt/ecs-deploy-runner")

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
	deployRunnerName := fmt.Sprintf("ecs-deploy-runner-%s", uniqueID)

	// Setup ECR repository
	defer test_structure.RunTestStage(t, "cleanup_ecr_repo", func() {
		deleteECRRepo(t, region, repository)
	})
	test_structure.RunTestStage(t, "setup_ecr_repo", func() {
		repositoryUri := createECRRepo(t, region, repository)
		test_structure.SaveString(t, workingDir, "EcrRepositoryUri", repositoryUri)
	})
	repositoryUri := test_structure.LoadString(t, workingDir, "EcrRepositoryUri")
	deployRunnerImg := fmt.Sprintf("%s:%s", repositoryUri, deployRunnerImgTag)
	kanikoImg := fmt.Sprintf("%s:%s", repositoryUri, kanikoImgTag)

	// Setup private ssh key in secrets manager
	defer test_structure.RunTestStage(t, "cleanup_ssh_private_key", func() {
		sshSecretsManagerArn := test_structure.LoadString(t, workingDir, "SSHKeySecretsManagerArn")
		deleteSecretsManagerSecret(t, region, sshSecretsManagerArn)

		patSecretsManagerArn := test_structure.LoadString(t, workingDir, "PATSecretsManagerArn")
		deleteSecretsManagerSecret(t, region, patSecretsManagerArn)
	})
	test_structure.RunTestStage(t, "setup_ssh_private_key", func() {
		sshKeyName := fmt.Sprintf("ECRDeployRunnerTestSSHKey-%s", uniqueID)
		privateKey := loadSSHKey(t)
		sshSecretsManagerArn := loadSecretToSecretsManager(t, region, sshKeyName, privateKey)
		test_structure.SaveString(t, workingDir, "SSHKeySecretsManagerArn", sshSecretsManagerArn)

		gitPatName := fmt.Sprintf("ECRDeployRunnerTestGitPAT-%s", uniqueID)
		gitPatSecretsManagerArn := loadSecretToSecretsManager(t, region, gitPatName, os.Getenv(gitPATEnvName))
		test_structure.SaveString(t, workingDir, "PATSecretsManagerArn", gitPatSecretsManagerArn)
	})
	sshSecretsManagerArn := test_structure.LoadString(t, workingDir, "SSHKeySecretsManagerArn")
	gitPatSecretsManagerArn := test_structure.LoadString(t, workingDir, "PATSecretsManagerArn")

	// Build and push docker image
	defer test_structure.RunTestStage(t, "delete_docker_image", func() {
		deleteDockerImage(t, deployRunnerImg)
		deleteDockerImage(t, kanikoImg)
	})
	test_structure.RunTestStage(t, "build_docker_image", func() {
		// deploy-runner docker image
		deployRunnerBuildOpts := &docker.BuildOptions{
			Tags: []string{deployRunnerImg},
			BuildArgs: []string{
				"GITHUB_OAUTH_TOKEN",
				fmt.Sprintf("module_ci_tag='%s'", moduleCITag),
			},
			OtherOptions: []string{"--no-cache"},
		}
		gitCloneAndDockerBuild(t, moduleCIRepo, moduleCITag, "modules/ecs-deploy-runner/docker/deploy-runner", deployRunnerBuildOpts)

		// kaniko docker image
		kanikoBuildOpts := &docker.BuildOptions{
			Tags: []string{kanikoImg},
			BuildArgs: []string{
				"GITHUB_OAUTH_TOKEN",
				fmt.Sprintf("module_ci_tag='%s'", moduleCITag),
			},
			OtherOptions: []string{"--no-cache"},
		}
		gitCloneAndDockerBuild(t, moduleCIRepo, moduleCITag, "modules/ecs-deploy-runner/docker/kaniko", kanikoBuildOpts)
	})
	test_structure.RunTestStage(t, "push_docker_image", func() {
		pushCmd := shell.Command{
			Command: "bash",
			Args: []string{
				"-c",
				fmt.Sprintf(
					"eval $(aws ecr get-login --no-include-email --region %s) && docker push %s && docker push %s",
					region,
					deployRunnerImg,
					kanikoImg,
				),
			},
		}
		shell.RunCommand(t, pushCmd)
	})

	// Deploy the ECS deploy runner
	gitUserEmail, gitUserName := getGitUserInfo(t, os.Getenv(gitPATEnvName))
	deployOpts := &terraform.Options{
		TerraformDir: modulePath,
		Vars: map[string]interface{}{
			"aws_region": region,
			"name":       deployRunnerName,
			"docker_image_builder_config": map[string]interface{}{
				"container_image": map[string]string{
					"docker_image": repositoryUri,
					"docker_tag":   kanikoImgTag,
				},
				"iam_policy": map[string]interface{}{
					"ECRAccess": map[string]interface{}{
						"effect":    "Allow",
						"actions":   []string{"ecr:*"},
						"resources": []string{"*"},
					},
				},
				"allowed_repos": []string{serviceCatalogRepo},
				"git_config": map[string]interface{}{
					"username_secrets_manager_arn": gitPatSecretsManagerArn,
					"password_secrets_manager_arn": nil,
				},
				"secrets_manager_env_vars": map[string]interface{}{},
			},
			"ami_builder_config": map[string]interface{}{
				"container_image": map[string]string{
					"docker_image": repositoryUri,
					"docker_tag":   deployRunnerImgTag,
				},
				"iam_policy": map[string]interface{}{
					"EC2Access": map[string]interface{}{
						"effect":    "Allow",
						"actions":   []string{"ec2:*"},
						"resources": []string{"*"},
					},
				},
				"allowed_repos": []string{serviceCatalogRepo},
				"repo_access_ssh_key_secrets_manager_arn": sshSecretsManagerArn,
				"secrets_manager_env_vars":                map[string]interface{}{},
			},
			"terraform_planner_config": map[string]interface{}{
				"container_image": map[string]string{
					"docker_image": repositoryUri,
					"docker_tag":   deployRunnerImgTag,
				},
				"iam_policy":                              map[string]interface{}{},
				"infrastructure_live_repositories":        []string{serviceCatalogRepo},
				"repo_access_ssh_key_secrets_manager_arn": sshSecretsManagerArn,
				"secrets_manager_env_vars":                map[string]interface{}{},
			},
			"terraform_applier_config": map[string]interface{}{
				"container_image": map[string]string{
					"docker_image": repositoryUri,
					"docker_tag":   deployRunnerImgTag,
				},
				"iam_policy":                       map[string]interface{}{},
				"infrastructure_live_repositories": []string{serviceCatalogRepo},
				"allowed_update_variable_names":    []string{"tag", "docker_tag", "ami_version_tag", "ami"},
				"allowed_apply_git_refs":           []string{"master"},
				"machine_user_git_info": map[string]interface{}{
					"name":  gitUserName,
					"email": gitUserEmail,
				},
				"repo_access_ssh_key_secrets_manager_arn": sshSecretsManagerArn,
				"secrets_manager_env_vars":                map[string]interface{}{},
			},
		},
	}
	defer test_structure.RunTestStage(t, "destroy_deploy_runner", func() {
		terraform.Destroy(t, deployOpts)
	})
	test_structure.RunTestStage(t, "apply_deploy_runner", func() {
		terraform.InitAndApply(t, deployOpts)
	})
}
