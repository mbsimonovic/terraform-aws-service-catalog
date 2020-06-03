package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"testing"
	"time"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ecr"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/gruntwork-io/gruntwork-cli/errors"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/stretchr/testify/require"

	"github.com/gruntwork-io/module-ci/modules/infrastructure-deployer/deploy"
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

// invokeDeployRunnerLambdaE will take the provided deploy args and directly invoke the Lambda function using the AWS
// SDK.
func invokeDeployRunnerLambdaE(t *testing.T, args deploy.DeployArgs, region string, functionArn string) (*deploy.InvokeResp, error) {
	session, err := deploy.NewAuthenticatedSessionFromDefaultCredentials(region)
	if err != nil {
		return nil, err
	}
	resp, err := deploy.InvokeLambda(session, functionArn, args)
	return resp, errors.Unwrap(err)
}

// waitForECSTaskToFinish will continuously check the ECS task referenced in the invoke response until it reaches the
// STOPPED state, or the check times out. The timeout setting is 5 minutes.
func waitForECSTaskToFinish(t *testing.T, region string, resp *deploy.InvokeResp) {
	ecsClient := aws.NewEcsClient(t, region)
	retry.DoWithRetry(
		t,
		"wait for task to finish",
		// 5 minutes: 30 tries, 10 seconds in between each trial
		30, 10*time.Second,
		func() (string, error) {
			input := &ecs.DescribeTasksInput{
				Cluster: awsgo.String(resp.ClusterArn),
				Tasks:   awsgo.StringSlice([]string{resp.TaskArn}),
			}
			resp, err := ecsClient.DescribeTasks(input)
			if err != nil {
				return "", err
			}

			if len(resp.Tasks) != 1 {
				return "", fmt.Errorf("Could not find deploy task.")
			}

			task := resp.Tasks[0]
			lastStatus := awsgo.StringValue(task.LastStatus)
			if lastStatus != "STOPPED" {
				return "", fmt.Errorf("Deploy task has not stopped yet. Last status %s", lastStatus)
			}
			return "deploy task has stopped", nil
		},
	)
}

func deleteDockerImage(t *testing.T, img string) {
	cmd := shell.Command{
		Command: "docker",
		Args:    []string{"rmi", img},
	}
	shell.RunCommand(t, cmd)
}

func createECRRepo(t *testing.T, region string, name string) string {
	client := newECRClient(t, region)
	resp, err := client.CreateRepository(&ecr.CreateRepositoryInput{RepositoryName: awsgo.String(name)})
	require.NoError(t, err)
	return awsgo.StringValue(resp.Repository.RepositoryUri)
}

// deleteECRRepo will force delete the ECR repo by deleting all images prior to deleting the ECR repository.
func deleteECRRepo(t *testing.T, region string, name string) {
	client := newECRClient(t, region)
	_, err := client.BatchDeleteImage(&ecr.BatchDeleteImageInput{
		RepositoryName: awsgo.String(name),
		ImageIds: []*ecr.ImageIdentifier{
			&ecr.ImageIdentifier{ImageTag: awsgo.String("v1")},
		},
	})
	require.NoError(t, err)
	_, err = client.DeleteRepository(&ecr.DeleteRepositoryInput{RepositoryName: awsgo.String(name)})
	require.NoError(t, err)
}

func loadSSHKeyToSecretsManager(t *testing.T, region string, uniqueID string) string {
	client := newSecretsManagerClient(t, region)

	privateKey := loadSSHKey(t)
	name := fmt.Sprintf("ECRDeployRunnerTestSSHKey-%s", uniqueID)
	input := &secretsmanager.CreateSecretInput{
		Name:         awsgo.String(name),
		SecretString: awsgo.String(privateKey),
	}
	out, err := client.CreateSecret(input)
	require.NoError(t, err)
	return awsgo.StringValue(out.ARN)
}

func deleteSSHKeySecret(t *testing.T, region string, arn string) {
	client := newSecretsManagerClient(t, region)

	input := &secretsmanager.DeleteSecretInput{
		ForceDeleteWithoutRecovery: awsgo.Bool(true),
		SecretId:                   awsgo.String(arn),
	}
	_, err := client.DeleteSecret(input)
	require.NoError(t, err)
}

func newECRClient(t *testing.T, region string) *ecr.ECR {
	sess, err := aws.NewAuthenticatedSession(region)
	require.NoError(t, err)
	return ecr.New(sess)
}

func newSecretsManagerClient(t *testing.T, region string) *secretsmanager.SecretsManager {
	sess, err := aws.NewAuthenticatedSession(region)
	require.NoError(t, err)
	return secretsmanager.New(sess)
}

// loadSSHKey will load a private SSH key referenced at a path set using the environment variable
// "TERRATEST_SSH_PRIVATE_KEY_PATH" into memory.
func loadSSHKey(t *testing.T) string {
	sshPrivKeyPath := os.Getenv("TERRATEST_SSH_PRIVATE_KEY_PATH")
	contents, err := ioutil.ReadFile(sshPrivKeyPath)
	require.NoError(t, err)
	return string(contents)
}
