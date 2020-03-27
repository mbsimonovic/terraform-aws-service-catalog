package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	awssdk "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/kms"

	"github.com/stretchr/testify/require"
)

func TestOpenvpnServer(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_build_ami", "true")
	// os.Setenv("SKIP_deploy_terraform", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")
	// os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/mgmt/openvpn-server"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)

		awsRegion := test_structure.LoadString(t, testFolder, "region")
		kmsKeyArn := test_structure.LoadString(t, testFolder, "kmsKeyArn")
		deleteKMSKey(t, awsRegion, kmsKeyArn)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		branchName := git.GetCurrentBranchName(t)
		awsRegion := aws.GetRandomStableRegion(t, regionsForEc2Tests, nil)

		packerOptions := &packer.Options{
			Template: "../modules/mgmt/openvpn-server/openvpn-server.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)

		test_structure.SaveString(t, testFolder, "region", awsRegion)
		test_structure.SaveArtifactID(t, testFolder, amiId)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		name := fmt.Sprintf("openvpn-server-%s", random.UniqueId())
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueId := random.UniqueId()
		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)

		kmsKeyARN := createKMSKey(t, awsRegion, uniqueId)

		s3BucketName := "openvpn-test-" + strings.ToLower(uniqueId)

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"aws_region":            awsRegion,
				"name":                  name,
				"ami_id":                amiId,
				"base_domain_name_tags": domainNameTagsForTest,
				"keypair_name":          awsKeyPair.Name,
				"kms_key_arn":           kmsKeyARN,
				"backup_bucket_name":    s3BucketName,
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
		test_structure.SaveString(t, testFolder, "kmsKeyArn", kmsKeyARN)
		test_structure.SaveString(t, testFolder, "s3BucketName", s3BucketName)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		ip := terraform.OutputRequired(t, terraformOptions, "public_ip")
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		testSSH(t, ip, "ubuntu", awsKeyPair)
	})

}

func createKMSKey(t *testing.T, region, uniqueId string) string {
	sess, err := session.NewSession(&awssdk.Config{
		Region: awssdk.String(region)},
	)
	require.NoError(t, err)

	svc := kms.New(sess)
	description := fmt.Sprintf("openvpn-server-test-%s", uniqueId)
	input := &kms.CreateKeyInput{
		Description: awssdk.String(description),
	}
	result, err := svc.CreateKey(input)
	require.NoError(t, err)

	return awssdk.StringValue(result.KeyMetadata.Arn)
}

func deleteKMSKey(t *testing.T, region, keyArn string) {
	sess, err := session.NewSession(&awssdk.Config{
		Region: awssdk.String(region)},
	)
	require.NoError(t, err)

	svc := kms.New(sess)
	input := &kms.ScheduleKeyDeletionInput{
		KeyId:               awssdk.String(keyArn),
		PendingWindowInDays: awssdk.Int64(7), // 7 is the minimum
	}
	_, err = svc.ScheduleKeyDeletion(input)
	require.NoError(t, err)
}
