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
	//t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_setup", "true")
	// os.Setenv("SKIP_deploy_cluster", "true")
	// os.Setenv("SKIP_validate_cluster", "true")
	// os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/elasticsearch")
	testFolderPublic := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/data-stores/elasticsearch-public")

	testCases := []struct {
		name     string
		setup    func()
		deploy   func()
		validate func()
		cleanup  func()
	}{
		{
			"VPC-based Cluster",
			func() {
				// Redundantly restrict and allow regions to safeguard against future changes to the allowed regions list.
				// I.e., ap-northeast-2 is known to fail on t2.micro instance types and us/eu regions are known to succeed.
				awsRegion := aws.GetRandomStableRegion(t, []string{"us-east-1", "us-west-1", "eu-west-1"}, []string{"ap-northeast-2"})
				test_structure.SaveString(t, testFolder, "region", awsRegion)

				uniqueID := strings.ToLower(random.UniqueId())
				test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

				awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
				test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
			},

			func() {
				awsRegion := test_structure.LoadString(t, testFolder, "region")
				uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")
				awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

				terraformOptions := createElasticsearchTerraformOptions(t, testFolder, awsRegion, uniqueID, awsKeyPair.Name)
				test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
				terraform.InitAndApply(t, terraformOptions)
			},

			func() {
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
			},

			func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
				terraform.Destroy(t, terraformOptions)
				awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
				aws.DeleteEC2KeyPair(t, awsKeyPair)
			},
		},

		{
			"Public Access Cluster",
			func() {
				// Redundantly restrict and allow regions to safeguard against future changes to the allowed regions list.
				// I.e., ap-northeast-2 is known to fail on t2.micro instance types and us/eu regions are known to succeed.
				awsRegion := aws.GetRandomStableRegion(t, []string{"us-east-1", "us-west-1", "eu-west-1"}, []string{"ap-northeast-2"})
				test_structure.SaveString(t, testFolderPublic, "region", awsRegion)

				uniqueID := strings.ToLower(random.UniqueId())
				test_structure.SaveString(t, testFolderPublic, "uniqueID", uniqueID)
			},

			func() {
				awsRegion := test_structure.LoadString(t, testFolderPublic, "region")
				uniqueID := test_structure.LoadString(t, testFolderPublic, "uniqueID")

				// terraformOptions := createElasticsearchTerraformOptions(t, testFolderPublic, awsRegion, uniqueID, "", []string{"arn:aws:iam::087285199408:user/circle-ci-test"})
				terraformOptions := createElasticsearchTerraformOptions(t, testFolderPublic, awsRegion, uniqueID, "")
				test_structure.SaveTerraformOptions(t, testFolderPublic, terraformOptions)
				terraform.InitAndApply(t, terraformOptions)
			},

			func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, testFolderPublic)
				awsRegion := test_structure.LoadString(t, testFolderPublic, "region")

				terraform.OutputRequired(t, terraformOptions, "cluster_arn")
				terraform.OutputRequired(t, terraformOptions, "cluster_domain_id")
				endpoint := terraform.OutputRequired(t, terraformOptions, "cluster_endpoint")
				terraform.OutputRequired(t, terraformOptions, "cluster_security_group_id")

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
				// --silent --location --fail --show-error -XGET https://search-acme-test-aes-or2dig-fzlizewuolwrgkwrxhac2kediu.eu-west-1.es.amazonaws.com/_cluster/settings?pretty=true
			},

			func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, testFolderPublic)
				terraform.Destroy(t, terraformOptions)
			},
		},
	}

	for _, testCase := range testCases {
		testCase := testCase
		t.Run("Elasticsearch", func(*testing.T) {
			t.Parallel()
			defer test_structure.RunTestStage(t, "cleanup", testCase.cleanup)
			test_structure.RunTestStage(t, "setup", testCase.setup)
			test_structure.RunTestStage(t, "deploy_cluster", testCase.deploy)
			test_structure.RunTestStage(t, "validate_cluster", testCase.validate)
		})
	}
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
