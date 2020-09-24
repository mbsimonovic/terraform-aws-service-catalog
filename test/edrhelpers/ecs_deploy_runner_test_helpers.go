package edrhelpers

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ecr"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/google/go-github/v32/github"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/oauth2"
)

const (
	ModuleCIRepo = "git@github.com:gruntwork-io/module-ci.git"
	ModuleCITag  = "v0.28.1"
)

var ECSFargateRegions = []string{
	"us-east-1",
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"eu-west-2",
	"eu-west-3",
	"eu-central-1",
	"ap-northeast-1",
	"ap-northeast-2",
	"ap-southeast-1",
	"ap-southeast-2",
	"ca-central-1",
}

// GitCloneAndDockerBuild builds a new Docker image from a given Git repo
func GitCloneAndDockerBuild(
	t *testing.T,
	repo string,
	ref string,
	path string,
	dockerBuildOpts *docker.BuildOptions,
) {
	workingDir, err := ioutil.TempDir("", "")
	require.NoError(t, err)
	defer os.RemoveAll(workingDir)

	cloneCmd := shell.Command{
		Command: "git",
		Args:    []string{"clone", repo, workingDir},
	}
	shell.RunCommand(t, cloneCmd)

	checkoutCmd := shell.Command{
		Command:    "git",
		Args:       []string{"checkout", ref},
		WorkingDir: workingDir,
	}
	shell.RunCommand(t, checkoutCmd)

	contextPath := filepath.Join(workingDir, path)
	docker.Build(t, contextPath, dockerBuildOpts)
}

// DeleteDockerImage removes a docker image using the Docker CLI
func DeleteDockerImage(t *testing.T, img string) {
	cmd := shell.Command{
		Command: "docker",
		Args:    []string{"rmi", img},
	}
	shell.RunCommand(t, cmd)
}

// CreateECRRepo creates a new ECR Repository
func CreateECRRepo(t *testing.T, region string, name string) string {
	client := NewECRClient(t, region)
	resp, err := client.CreateRepository(&ecr.CreateRepositoryInput{RepositoryName: awsgo.String(name)})
	require.NoError(t, err)
	return awsgo.StringValue(resp.Repository.RepositoryUri)
}

// DeleteECRRepo will force delete the ECR repo by deleting all images prior to deleting the ECR repository.
func DeleteECRRepo(t *testing.T, region string, name string) {
	client := NewECRClient(t, region)

	resp, err := client.ListImages(&ecr.ListImagesInput{RepositoryName: awsgo.String(name)})
	require.NoError(t, err)

	_, err = client.BatchDeleteImage(&ecr.BatchDeleteImageInput{
		RepositoryName: awsgo.String(name),
		ImageIds:       resp.ImageIds,
	})
	require.NoError(t, err)

	_, err = client.DeleteRepository(&ecr.DeleteRepositoryInput{RepositoryName: awsgo.String(name)})
	require.NoError(t, err)
}

// NewECRClient returns a client for the Elastic Container Registry
func NewECRClient(t *testing.T, region string) *ecr.ECR {
	sess, err := aws.NewAuthenticatedSession(region)
	require.NoError(t, err)
	return ecr.New(sess)
}

// LoadSSHKey will load a private SSH key referenced at a path set using the environment variable
// "TERRATEST_SSH_PRIVATE_KEY_PATH" into memory.
func LoadSSHKey(t *testing.T) string {
	sshPrivKeyPath := os.Getenv("TERRATEST_SSH_PRIVATE_KEY_PATH")
	contents, err := ioutil.ReadFile(sshPrivKeyPath)
	require.NoError(t, err)
	return string(contents)
}

// GetGitUserInfo returns the email address and name of the current github user
func GetGitUserInfo(t *testing.T, token string) (string, string) {
	ctx, ghClient := NewGithubClient(token)
	authenticatedUser, _, err := ghClient.Users.Get(ctx, "")
	require.NoError(t, err)
	return authenticatedUser.GetEmail(), authenticatedUser.GetName()
}

// NeGithubClient takes a GitHub PAT and returns a GitHub API client
func NewGithubClient(token string) (context.Context, *github.Client) {
	ctx := context.Background()
	oauth2TokenSource := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: token},
	)
	oauth2Client := oauth2.NewClient(ctx, oauth2TokenSource)

	return ctx, github.NewClient(oauth2Client)
}

// RequireGruntworkInstaller ensures that the `gruntwork-install` helper is available in the environment
func RequireGruntworkInstaller(t *testing.T) {
	cmd := shell.Command{
		Command: "gruntwork-install",
		Args:    []string{"--help"},
	}
	shell.RunCommand(t, cmd)
}

// InstallInfrastructureDeployer uses gruntwork-install to install the infrastructure-deployer tool from the module-ci repo
func InstallInfrastructureDeployer(t *testing.T, targetDir string, tag string) {
	cmd := shell.Command{
		Command: "gruntwork-install",
		Args: []string{
			"--binary-name", "infrastructure-deployer",
			"--repo", "https://github.com/gruntwork-io/module-ci",
			"--tag", tag,
			"--binary-install-dir", targetDir,
		},
	}
	shell.RunCommand(t, cmd)
	require.Truef(t, files.FileExists(filepath.Join(targetDir, "infrastructure-deployer")), "infrastructure-deployer was not installed in the target dir %s", targetDir)
}

// InvokeInfrastructureDeployer invokes the infrastructure-deployer CLI using a generic test module in module-ci to
// smoke test the stack. This will also validate that the correct launch type was used, so that we can verify both EC2
// and Fargate compatibility of the service module.
func InvokeInfrastructureDeployer(
	t *testing.T,
	terraformOptions *terraform.Options,
	infraDeployerBinPath string,
	ecsLaunchType string,
) {
	invokerFunctionArn := terraform.Output(t, terraformOptions, "invoker_function_arn")
	ecsClusterArn := terraform.Output(t, terraformOptions, "ecs_cluster_arn")
	region := terraformOptions.Vars["aws_region"].(string)
	cmd := shell.Command{
		Command: infraDeployerBinPath,
		Args: []string{
			"--aws-region", region,
			"--invoker-function-id", invokerFunctionArn,
			"--task-launch-type", ecsLaunchType,
			"--",
			"terraform-applier",
			"infrastructure-deploy-script",
			"--ref", "master",
			"--repo", ModuleCIRepo,
			"--deploy-path", "test/fixtures/tfpipeline/root/terragrunt",
			"--binary", "terragrunt",
			"--command", "apply",
		},
	}
	out := shell.RunCommandAndGetOutput(t, cmd)
	assert.Contains(t, out, "data = Hello world")
	assert.Contains(t, out, "\"terragrunt apply\" exited with code 0")
	AssertECSLaunchType(t, region, ecsClusterArn, out, ecsLaunchType)
}

// AssertECSLaunchType asserts that the actual launch type matches the expected launch type
func AssertECSLaunchType(t *testing.T, region string, ecsClusterArn string, launchLogs string, launchType string) {
	// extract the ECS task ARN from the logs
	re, err := regexp.Compile(
		fmt.Sprintf(
			`Waiting for ECS task (arn:aws:ecs:%s:%s:task/.+) to start`,
			region,
			aws.GetAccountId(t),
		),
	)
	require.NoError(t, err)
	matches := re.FindStringSubmatch(launchLogs)
	require.Equal(t, len(matches), 2)
	ecsTaskArn := matches[1]

	// Validate the launch type of the task
	ecsSvc := aws.NewEcsClient(t, region)
	out, err := ecsSvc.DescribeTasks(&ecs.DescribeTasksInput{
		Cluster: awsgo.String(ecsClusterArn),
		Tasks:   awsgo.StringSlice([]string{ecsTaskArn}),
	})
	require.NoError(t, err)
	require.Equal(t, len(out.Tasks), 1)
	ecsTask := out.Tasks[0]
	assert.Equal(t, launchType, awsgo.StringValue(ecsTask.LaunchType))
}
