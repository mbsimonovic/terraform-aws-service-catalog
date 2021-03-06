package mgmt

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
	"github.com/gruntwork-io/module-ci/test/edrhelpers"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

const (
	serviceCatalogRepo = "git@github.com:gruntwork-io/aws-service-catalog.git"
	moduleCITag        = "v0.45.4"
	deployRunnerImgTag = "deploy-runner-v1"
	kanikoImgTag       = "kaniko-v1"

	gitPATEnvName = "GITHUB_OAUTH_TOKEN"
)

// TestEcsDeployRunner tests the ECS Deploy Runner module.
// The environment variable TERRATEST_SSH_PRIVATE_KEY_PATH must be set to a valid path containing an SSH private key
// that can be used to clone Gruntwork Repos.
func TestEcsDeployRunner(t *testing.T) {
	t.Parallel()

	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_build_worker_ami", "true")
	//os.Setenv("SKIP_setup_ecr_repo", "true")
	//os.Setenv("SKIP_setup_ssh_private_key", "true")
	//os.Setenv("SKIP_build_docker_image", "true")
	//os.Setenv("SKIP_push_docker_image", "true")
	//os.Setenv("SKIP_apply_deploy_runner", "true")
	//os.Setenv("SKIP_validate_deploy_runner_ec2", "true")
	//os.Setenv("SKIP_validate_deploy_runner_fargate", "true")
	//os.Setenv("SKIP_validate_deploy_runner_schedule", "true")
	//os.Setenv("SKIP_destroy_deploy_runner", "true")
	//os.Setenv("SKIP_delete_docker_image", "true")
	//os.Setenv("SKIP_cleanup_ssh_private_key", "true")
	//os.Setenv("SKIP_cleanup_ecr_repo", "true")
	//os.Setenv("SKIP_cleanup_worker_ami", "true")

	// Test prerequisite checks:
	// - Must have GITHUB_OAUTH_TOKEN defined so that `gruntwork-install` works in packer and docker.
	// - Must have TERRATEST_SSH_PRIVATE_KEY_PATH defined.
	// - Make sure infrastructure-deployer CLI is available
	test.RequireEnvVar(t, "GITHUB_OAUTH_TOKEN")
	test.RequireEnvVar(t, "TERRATEST_SSH_PRIVATE_KEY_PATH")
	edrhelpers.RequireGruntworkInstaller(t)

	modulePath := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/mgmt/ecs-deploy-runner")
	infraDeployerBinPath := filepath.Join(modulePath, "infrastructure-deployer")

	// Create a directory path that won't conflict
	workingDir := filepath.Join(".", "stages", t.Name())
	branchName := git.GetCurrentBranchName(t)

	// Setup test environment by choosing a region and generating a unique ID for namespacing resources.
	test_structure.RunTestStage(t, "setup", func() {
		region := aws.GetRandomStableRegion(t, edrhelpers.ECSFargateRegions, nil)
		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, workingDir, "UniqueID", uniqueID)
		test_structure.SaveString(t, workingDir, "AwsRegion", region)

		// Use gruntwork-installer to install infrastructure-deployer into module dir so we can use it for testing
		edrhelpers.InstallInfrastructureDeployer(t, modulePath, moduleCITag)
	})
	uniqueID := test_structure.LoadString(t, workingDir, "UniqueID")
	region := test_structure.LoadString(t, workingDir, "AwsRegion")
	repository := fmt.Sprintf("gruntwork/ecs-deploy-runner-%s", uniqueID)
	deployRunnerName := fmt.Sprintf("ecs-deploy-runner-%s", uniqueID)

	// Build AMI for EC2 worker pool
	defer test_structure.RunTestStage(t, "cleanup_worker_ami", func() {
		amiId := test_structure.LoadArtifactID(t, workingDir)
		awsRegion := test_structure.LoadString(t, workingDir, "AwsRegion")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})
	test_structure.RunTestStage(t, "build_worker_ami", func() {
		awsRegion := test_structure.LoadString(t, workingDir, "AwsRegion")
		packerOptions := &packer.Options{
			Template: "../../modules/mgmt/ecs-deploy-runner/ecs-deploy-runner-worker-al2.pkr.hcl",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
				"instance_type":       aws.GetRecommendedInstanceType(t, region, []string{"t2.micro", "t3.micro"}),
				"encrypt_boot":        "false",
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}
		amiId := packer.BuildArtifact(t, packerOptions)
		test_structure.SaveArtifactID(t, workingDir, amiId)
	})

	// Setup ECR repository
	defer test_structure.RunTestStage(t, "cleanup_ecr_repo", func() {
		repo := aws.GetECRRepo(t, region, repository)
		aws.DeleteECRRepo(t, region, repo)
	})
	test_structure.RunTestStage(t, "setup_ecr_repo", func() {
		repositoryUri := awsgo.StringValue(aws.CreateECRRepo(t, region, repository).RepositoryUri)
		test_structure.SaveString(t, workingDir, "EcrRepositoryUri", repositoryUri)
	})
	repositoryUri := test_structure.LoadString(t, workingDir, "EcrRepositoryUri")
	deployRunnerImg := fmt.Sprintf("%s:%s", repositoryUri, deployRunnerImgTag)
	kanikoImg := fmt.Sprintf("%s:%s", repositoryUri, kanikoImgTag)

	// Setup private ssh key in secrets manager
	defer test_structure.RunTestStage(t, "cleanup_ssh_private_key", func() {
		sshSecretsManagerArn := test_structure.LoadString(t, workingDir, "SSHKeySecretsManagerArn")
		aws.DeleteSecret(t, region, sshSecretsManagerArn, true)

		patSecretsManagerArn := test_structure.LoadString(t, workingDir, "PATSecretsManagerArn")
		aws.DeleteSecret(t, region, patSecretsManagerArn, true)
	})
	test_structure.RunTestStage(t, "setup_ssh_private_key", func() {
		sshKeyName := fmt.Sprintf("ECRDeployRunnerTestSSHKey-%s", uniqueID)
		privateKey := edrhelpers.LoadSSHKey(t)
		sshSecretsManagerArn := aws.CreateSecretStringWithDefaultKey(t, region, sshKeyName, sshKeyName, privateKey)
		test_structure.SaveString(t, workingDir, "SSHKeySecretsManagerArn", sshSecretsManagerArn)

		gitPatName := fmt.Sprintf("ECRDeployRunnerTestGitPAT-%s", uniqueID)
		gitPatSecretsManagerArn := aws.CreateSecretStringWithDefaultKey(t, region, gitPatName, gitPatName, os.Getenv(gitPATEnvName))
		test_structure.SaveString(t, workingDir, "PATSecretsManagerArn", gitPatSecretsManagerArn)
	})
	sshSecretsManagerArn := test_structure.LoadString(t, workingDir, "SSHKeySecretsManagerArn")
	gitPatSecretsManagerArn := test_structure.LoadString(t, workingDir, "PATSecretsManagerArn")

	// Build and push docker image
	defer test_structure.RunTestStage(t, "delete_docker_image", func() {
		edrhelpers.DeleteDockerImage(t, deployRunnerImg)
		edrhelpers.DeleteDockerImage(t, kanikoImg)
	})
	test_structure.RunTestStage(t, "build_docker_image", func() {
		buildArgs := []string{
			"GITHUB_OAUTH_TOKEN",
			fmt.Sprintf("module_ci_tag=%s", moduleCITag),
		}
		otherOptions := []string{"--no-cache"}

		// deploy-runner docker image
		deployRunnerBuildOpts := &docker.BuildOptions{
			Tags:         []string{deployRunnerImg},
			BuildArgs:    buildArgs,
			OtherOptions: otherOptions,
		}
		edrhelpers.GitCloneAndDockerBuild(t, edrhelpers.ModuleCIRepo, moduleCITag, "modules/ecs-deploy-runner/docker/deploy-runner", deployRunnerBuildOpts)

		// kaniko docker image
		kanikoBuildOpts := &docker.BuildOptions{
			Tags:         []string{kanikoImg},
			BuildArgs:    buildArgs,
			OtherOptions: otherOptions,
		}
		edrhelpers.GitCloneAndDockerBuild(t, edrhelpers.ModuleCIRepo, moduleCITag, "modules/ecs-deploy-runner/docker/kaniko", kanikoBuildOpts)
	})
	test_structure.RunTestStage(t, "push_docker_image", func() {
		test.AuthECRAndPushImages(t, region, []string{deployRunnerImg, kanikoImg})
	})

	// Deploy the ECS deploy runner
	gitUserEmail, gitUserName := edrhelpers.GetGitUserInfo(t, os.Getenv(gitPATEnvName))
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
				"allowed_repos":       []string{serviceCatalogRepo},
				"allowed_repos_regex": []string{},
				"git_config": map[string]interface{}{
					"username_secrets_manager_arn": gitPatSecretsManagerArn,
					"password_secrets_manager_arn": nil,
				},
				"secrets_manager_env_vars": map[string]interface{}{},
				"environment_vars":         map[string]interface{}{},
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
				"allowed_repos":                           []string{serviceCatalogRepo},
				"allowed_repos_regex":                     []string{},
				"repo_access_ssh_key_secrets_manager_arn": sshSecretsManagerArn,
				"repo_access_https_tokens":                nil,
				"secrets_manager_env_vars":                map[string]interface{}{},
				"environment_vars":                        map[string]interface{}{},
			},
			"terraform_planner_config": map[string]interface{}{
				"container_image": map[string]string{
					"docker_image": repositoryUri,
					"docker_tag":   deployRunnerImgTag,
				},
				"iam_policy":                              map[string]interface{}{},
				"infrastructure_live_repositories":        []string{serviceCatalogRepo, edrhelpers.ModuleCIRepo},
				"infrastructure_live_repositories_regex":  []string{},
				"repo_access_ssh_key_secrets_manager_arn": sshSecretsManagerArn,
				"repo_access_https_tokens":                nil,
				"secrets_manager_env_vars":                map[string]interface{}{},
				"environment_vars":                        map[string]interface{}{},
			},
			"terraform_applier_config": map[string]interface{}{
				"container_image": map[string]string{
					"docker_image": repositoryUri,
					"docker_tag":   deployRunnerImgTag,
				},
				"iam_policy":                             map[string]interface{}{},
				"infrastructure_live_repositories":       []string{serviceCatalogRepo, edrhelpers.ModuleCIRepo},
				"infrastructure_live_repositories_regex": []string{},
				"allowed_update_variable_names":          []string{"tag", "docker_tag", "ami_version_tag", "ami"},
				"allowed_apply_git_refs":                 []string{"master"},
				"machine_user_git_info": map[string]interface{}{
					"name":  gitUserName,
					"email": gitUserEmail,
				},
				"repo_access_ssh_key_secrets_manager_arn": sshSecretsManagerArn,
				"repo_access_https_tokens":                nil,
				"secrets_manager_env_vars":                map[string]interface{}{},
				"environment_vars":                        map[string]interface{}{},
			},
			"enable_ec2_worker_pool":          true,
			"ec2_worker_pool_ami_version_tag": branchName,
			"invoke_schedule": map[string]interface{}{
				"run_terraform_applier_help": map[string]string{
					"container_name":      "terraform-applier",
					"script":              "infrastructure-deploy-script",
					"args":                "--help",
					"schedule_expression": "rate(1 minute)",
				},
				"run_docker_image_builder_help": map[string]string{
					"container_name":      "docker-image-builder",
					"script":              "build-docker-image",
					"args":                "--help",
					"schedule_expression": "rate(1 minute)",
				},
			},
		},
	}
	defer test_structure.RunTestStage(t, "destroy_deploy_runner", func() {
		out, err := terraform.DestroyE(t, deployOpts)
		// Ignore destroy errors if output contains expected terraform error from bug. This happens because of a
		// terraform bug around handling providers in modules, which is necessary for our multiregion modules to work.
		// See https://github.com/gruntwork-io/module-security/issues/320 for more info (note that this issue is talking
		// about import, but we are encountering the same issue on destroy).
		if !strings.Contains(out, "Invalid AWS Region") {
			require.NoError(t, err)
		} else if err != nil {
			logger.Logf(t, "WARNING: Ignoring expected error on destroy.")
		}
	})
	test_structure.RunTestStage(t, "apply_deploy_runner", func() {
		terraform.InitAndApply(t, deployOpts)
	})

	// We use a synchronous subtest that then spawns two sub tests in parallel, so that the main thread blocks on
	// the two tests completing. This way, we ensure all the defer calls only happen after the subtests complete.
	t.Run("ECSLaunchType", func(t *testing.T) {
		t.Run("EC2", func(t *testing.T) {
			t.Parallel()
			test_structure.RunTestStage(t, "validate_deploy_runner_ec2", func() {
				edrhelpers.InvokeInfrastructureDeployer(t, deployOpts, infraDeployerBinPath, "EC2")
			})
		})
		t.Run("FARGATE", func(t *testing.T) {
			t.Parallel()
			test_structure.RunTestStage(t, "validate_deploy_runner_fargate", func() {
				edrhelpers.InvokeInfrastructureDeployer(t, deployOpts, infraDeployerBinPath, "FARGATE")
			})
		})
		t.Run("Schedule", func(t *testing.T) {
			t.Parallel()
			test_structure.RunTestStage(t, "validate_deploy_runner_schedule", func() {
				validateECSDeployRunnerPeriodicInvoke(t, deployOpts, region)
			})
		})
	})
}

func validateECSDeployRunnerPeriodicInvoke(t *testing.T, deployOpts *terraform.Options, awsRegion string) {
	logGroupName := terraform.OutputRequired(t, deployOpts, "cloudwatch_log_group_name")

	// Help text for infrastructure-deploy-script
	requireEDRExpectedLogEntry(
		t,
		awsRegion,
		logGroupName,
		"ecs-deploy-runner/terraform-applier",
		"Usage: infrastructure-deploy-script [OPTIONS]",
	)

	// Help text for build-docker-image
	requireEDRExpectedLogEntry(
		t,
		awsRegion,
		logGroupName,
		"ecs-deploy-runner/docker-image-builder",
		"Command to trigger a docker build using kaniko.",
	)
}

func requireEDRExpectedLogEntry(t *testing.T, awsRegion, logGroupName, logStreamPrefix, expectedLogEntry string) {
	description := "Looking in CloudWatch Logs to see if EDR was invoked"
	maxRetries := 10
	timeBetweenRetries := 30 * time.Second

	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		logStreamNames, err := getLogStreamNamesWithPrefix(t, awsRegion, logGroupName, logStreamPrefix)
		if err != nil {
			return "", err
		}

		for _, logStreamName := range logStreamNames {
			entries, err := aws.GetCloudWatchLogEntriesE(t, awsRegion, logStreamName, logGroupName)
			if err != nil {
				return "", err
			}

			for _, entry := range entries {
				if strings.Contains(entry, expectedLogEntry) {
					return entry, nil
				}
			}
		}

		return "", fmt.Errorf("Did not find entry '%s' in CloudWatch Logs", expectedLogEntry)
	})
}

func getLogStreamNamesWithPrefix(t *testing.T, awsRegion, logGroupName, logStreamPrefix string) ([]string, error) {
	svc := aws.NewCloudWatchLogsClient(t, awsRegion)

	input := cloudwatchlogs.DescribeLogStreamsInput{LogGroupName: awsgo.String(logGroupName)}
	output, err := svc.DescribeLogStreams(&input)
	if err != nil {
		return []string{}, err
	}

	logStreamNames := []string{}
	for _, logStream := range output.LogStreams {
		logStreamName := awsgo.StringValue(logStream.LogStreamName)
		if strings.HasPrefix(logStreamName, logStreamPrefix) {
			logStreamNames = append(logStreamNames, logStreamName)
		}
	}

	return logStreamNames, nil
}
