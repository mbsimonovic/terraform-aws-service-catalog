package test

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/signer/v4"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestElasticsearch(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_setup", "true")
	// os.Setenv("SKIP_deploy_cluster", "true")
	// os.Setenv("SKIP_validate_cluster", "true")
	// os.Setenv("SKIP_cleanup", "true")

	// Redundantly restrict and allow regions to safeguard against future changes to the allowed regions list.
	// I.e., ap-northeast-2 is known to fail on t2.micro instance types and us/eu regions are known to succeed.
	preferredRegions := []string{"us-east-1", "us-west-1", "eu-west-1"}
	excludedRegions := []string{"ap-northeast-2"}

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/elasticsearch")
	testFolderPublic := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/elasticsearch-public")

	testCases := []struct {
		name       string
		testFolder string
		hasKeyPair bool
	}{
		{
			"VPC-based Cluster",
			testFolder,
			true,
		},
		{
			"Public Access Cluster",
			testFolderPublic,
			false,
		},
	}

	for _, testCase := range testCases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			defer test_structure.RunTestStage(t, "cleanup", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, testCase.testFolder)
				terraform.Destroy(t, terraformOptions)
				if testCase.hasKeyPair {
					awsKeyPair := test_structure.LoadEc2KeyPair(t, testCase.testFolder)
					aws.DeleteEC2KeyPair(t, awsKeyPair)
				}
			})

			test_structure.RunTestStage(t, "setup", func() {
				awsRegion := aws.GetRandomStableRegion(t, preferredRegions, excludedRegions)
				test_structure.SaveString(t, testCase.testFolder, "region", awsRegion)

				uniqueID := strings.ToLower(random.UniqueId())
				test_structure.SaveString(t, testCase.testFolder, "uniqueID", uniqueID)

				if testCase.hasKeyPair {
					awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
					test_structure.SaveEc2KeyPair(t, testCase.testFolder, awsKeyPair)
				}
			})

			test_structure.RunTestStage(t, "deploy_cluster", func() {
				awsRegion := test_structure.LoadString(t, testCase.testFolder, "region")
				uniqueID := test_structure.LoadString(t, testCase.testFolder, "uniqueID")

				if testCase.hasKeyPair {

					awsKeyPair := test_structure.LoadEc2KeyPair(t, testCase.testFolder)

					terraformOptions := createElasticsearchTerraformOptions(t, testCase.testFolder, awsRegion, uniqueID, awsKeyPair.Name)
					test_structure.SaveTerraformOptions(t, testCase.testFolder, terraformOptions)
					terraform.InitAndApply(t, terraformOptions)
				} else {

					terraformOptions := createElasticsearchTerraformOptions(t, testCase.testFolder, awsRegion, uniqueID, "")
					test_structure.SaveTerraformOptions(t, testCase.testFolder, terraformOptions)
					terraform.InitAndApply(t, terraformOptions)
				}
			})

			test_structure.RunTestStage(t, "validate_cluster", func() {
				if testCase.testFolder == testFolder {
					validateCluster(t, testCase.testFolder)
				} else {
					validatePublicCluster(t, testCase.testFolder)
				}
			})
		})
	}
}

func validateCluster(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

	terraform.OutputRequired(t, terraformOptions, "cluster_arn")
	terraform.OutputRequired(t, terraformOptions, "cluster_domain_id")
	endpoint := terraform.OutputRequired(t, terraformOptions, "cluster_endpoint")
	terraform.OutputRequired(t, terraformOptions, "cluster_security_group_id")
	ip := terraform.OutputRequired(t, terraformOptions, "aws_instance_public_ip")

	awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
	curlResponse := testSSHCommand(
		t,
		ip,
		"ubuntu",
		awsKeyPair,
		fmt.Sprintf(
			"curl --silent --location --fail --show-error -XGET %s/_cluster/settings?pretty=true",
			fmt.Sprintf("https://%s", endpoint),
		),
	)
	logger.Log(t, "%s", curlResponse)
}

func validatePublicCluster(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	awsRegion := test_structure.LoadString(t, testFolder, "region")

	terraform.OutputRequired(t, terraformOptions, "cluster_arn")
	terraform.OutputRequired(t, terraformOptions, "cluster_domain_id")
	endpoint := terraform.OutputRequired(t, terraformOptions, "cluster_endpoint")
	require.Empty(t, terraform.Output(t, terraformOptions, "cluster_security_group_id"))

	// A public cluster with IAM arns should reject unsigned requests
	// and permit requests signed with the right credentials
	validateUnsignedRequest(t, endpoint)
	validateSignedRequest(t, endpoint, awsRegion)
}

func validateUnsignedRequest(t *testing.T, endpoint string) {
	curl := shell.Command{
		Command: "curl",
		Args: []string{
			"--silent",
			"--location",
			"--fail",
			"--show-error",
			"-XGET",
			fmt.Sprintf("https://%s/_cluster/settings?pretty=true", endpoint),
		},
	}

	// expect 403
	err := shell.RunCommandE(t, curl)
	require.Error(t, err)
}

func validateSignedRequest(t *testing.T, endpoint string, awsRegion string) {
	// Get credentials from environment variables and create the AWS Signature Version 4 signer
	credentials := credentials.NewEnvCredentials()
	signer := v4.NewSigner(credentials)

	// An HTTP client for sending the request
	client := &http.Client{}

	// Form the HTTP request
	req, err := http.NewRequest(http.MethodGet, fmt.Sprintf("https://%s/_cluster/settings?pretty=true", endpoint), nil)

	// Sign the request, send it, and print the response
	signer.Sign(req, nil, "es", awsRegion, time.Now())
	resp, err := client.Do(req)
	require.NoError(t, err)
	fmt.Print(resp.Status + "\n")
}

func createElasticsearchTerraformOptions(
	t *testing.T,
	terraformDir string,
	awsRegion string,
	uniqueID string,
	awsKeyPairName string,
) *terraform.Options {
	terraformOptions := createBaseTerraformOptions(t, terraformDir, awsRegion)
	terraformOptions.Vars["domain_name"] = fmt.Sprintf("acme-test-aes-%s", uniqueID)
	if awsKeyPairName != "" {
		terraformOptions.Vars["keypair_name"] = awsKeyPairName
	}
	return terraformOptions
}
