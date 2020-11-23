package test

import (
	"os"
	"strings"
	"testing"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestS3Bucket(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_access_logs", "true")
	//os.Setenv("SKIP_validate_replication", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := "../examples/for-learning-and-testing/data-stores/s3-bucket"

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		primaryRegion := aws.GetRandomRegion(t, regionsForEc2Tests, nil)
		// Choose a different region for cross-region replication
		replicaRegion := aws.GetRandomRegion(t, regionsForEc2Tests, []string{primaryRegion})
		uuid := strings.ToLower(random.UniqueId())

		test_structure.SaveString(t, testFolder, "primaryRegion", primaryRegion)
		test_structure.SaveString(t, testFolder, "replicaRegion", replicaRegion)
		test_structure.SaveString(t, testFolder, "uuid", uuid)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		primaryRegion := test_structure.LoadString(t, testFolder, "primaryRegion")
		replicaRegion := test_structure.LoadString(t, testFolder, "replicaRegion")
		uuid := test_structure.LoadString(t, testFolder, "uuid")

		terraformOptions := createBaseTerraformOptions(t, testFolder, primaryRegion)
		terraformOptions.Vars["primary_bucket"] = "test-bucket-primary-" + uuid
		terraformOptions.Vars["access_logging_bucket"] = "test-bucket-logs-" + uuid
		terraformOptions.Vars["replica_bucket"] = "test-bucket-replica-" + uuid
		terraformOptions.Vars["replica_aws_region"] = replicaRegion

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_access_logs", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		accessLogsBucket := terraform.OutputRequired(t, terraformOptions, "access_logging_bucket_name")
		primaryBucket := terraform.OutputRequired(t, terraformOptions, "primary_bucket_name")
		primaryRegion := test_structure.LoadString(t, testFolder, "primaryRegion")

		primaryClient := aws.NewS3Client(t, primaryRegion)

		// Since access logs can take a long time to appear in the bucket, we confirm the access logging setup
		// not by checking for the existence of logs objects, but by checking the logging configuration to the target
		// bucket is properly set.
		loggingOutput, err := primaryClient.GetBucketLogging(&s3.GetBucketLoggingInput{
			Bucket: awsgo.String(primaryBucket),
		})
		require.NoError(t, err)
		assert.Equal(t, accessLogsBucket, awsgo.StringValue(loggingOutput.LoggingEnabled.TargetBucket))
	})

	test_structure.RunTestStage(t, "validate_replication", func() {
		testFilePath := "./fixtures/simple-docker-img/Dockerfile"
		testFileKey := "config/Dockerfile"

		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		primaryBucket := terraform.OutputRequired(t, terraformOptions, "primary_bucket_name")
		primaryRegion := test_structure.LoadString(t, testFolder, "primaryRegion")

		testfile, err := os.Open(testFilePath)
		require.NoError(t, err)
		defer testfile.Close()

		// To test the replication, we upload a test file to the primary bucket and check the replication status
		// of the object immediately following the upload is either PENDING or COMPLETE. We do not check that the
		// object actually gets replicated to the replica bucket, since this can take a long time.
		primaryUploader := aws.NewS3Uploader(t, primaryRegion)
		_, err = primaryUploader.Upload(&s3manager.UploadInput{
			Bucket: awsgo.String(primaryBucket),
			Key:    awsgo.String(testFileKey),
			Body:   testfile,
		})
		require.NoError(t, err)

		primaryClient := aws.NewS3Client(t, primaryRegion)
		objectOutput, err := primaryClient.GetObject(&s3.GetObjectInput{
			Bucket: awsgo.String(primaryBucket),
			Key:    awsgo.String(testFileKey),
		})
		require.NoError(t, err)
		assert.Contains(t, []string{"PENDING", "COMPLETE"}, awsgo.StringValue(objectOutput.ReplicationStatus))
	})
}
