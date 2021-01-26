package services

import (
	"bytes"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const (
	// In order to give EC2 container instances long enough to register themselves with the cluster, we wait a configurable number of minutes
	MinsToWaitForClusterInstances = 3
	TestDomainName                = "gruntwork.in"
	TestHostedZoneId              = "Z2AJ7S3R6G9UYJ"
)

func TestEcsCluster(t *testing.T) {
	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_build_ami", "true")
	// os.Setenv("SKIP_deploy_cluster", "true")
	// os.Setenv("SKIP_validate_cluster", "true")
	// os.Setenv("SKIP_deploy_service", "true")
	// os.Setenv("SKIP_validate_service", "true")
	// os.Setenv("SKIP_destroy_service", "true")
	// os.Setenv("SKIP_destroy_cluster", "true")
	// os.Setenv("SKIP_cleanup_keypairs", "true")
	// os.Setenv("SKIP_cleanup_ami", "true")
	t.Parallel()

	ecsClusterTestFolder := "../examples/for-learning-and-testing/services/ecs-cluster"
	ecsServiceTestFolder := "../examples/for-learning-and-testing/services/ecs-service"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiID := test_structure.LoadArtifactID(t, ecsClusterTestFolder)
		awsRegion := test_structure.LoadString(t, ecsClusterTestFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiID)
	})

	defer test_structure.RunTestStage(t, "cleanup_keypairs", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, ecsClusterTestFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	// The ECS service needs to be torn down prior to the cluster - otherwise AWS will return an error if you try to destroy a cluster that
	// still has a service defined within it
	defer test_structure.RunTestStage(t, "destroy_cluster", func() {
		ecsClusterTerraformOptions := test_structure.LoadTerraformOptions(t, ecsClusterTestFolder)
		terraform.Destroy(t, ecsClusterTerraformOptions)
	})

	defer test_structure.RunTestStage(t, "destroy_service", func() {
		ecsServiceTerraformOptions := test_structure.LoadTerraformOptions(t, ecsServiceTestFolder)
		terraform.Destroy(t, ecsServiceTerraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		buildAmi(t, ecsClusterTestFolder)
	})

	test_structure.RunTestStage(t, "deploy_cluster", func() {
		deployECSCluster(t, ecsClusterTestFolder)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateECSCluster(t, ecsClusterTestFolder)
	})

	test_structure.RunTestStage(t, "deploy_service", func() {
		deployEcsService(t, ecsClusterTestFolder, ecsServiceTestFolder)
	})

	test_structure.RunTestStage(t, "validate_service", func() {
		validateECSService(t, ecsClusterTestFolder, ecsServiceTestFolder)
	})
}

func buildAmi(t *testing.T, testFolder string) {
	awsRegion := aws.GetRandomStableRegion(t, []string{"us-west-1"}, nil)
	test_structure.SaveString(t, testFolder, "region", awsRegion)

	branchName := git.GetCurrentBranchName(t)
	packerOptions := &packer.Options{
		Template: "../modules/services/ecs-cluster/ecs-node-al2.json",
		Vars: map[string]string{
			"aws_region":          awsRegion,
			"service_catalog_ref": branchName,
			"version_tag":         branchName,
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	amiID := packer.BuildArtifact(t, packerOptions)
	test_structure.SaveArtifactID(t, testFolder, amiID)

	uniqueID := random.UniqueId()
	test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

	clusterName := fmt.Sprintf("ecs-service-catalog-%s", strings.ToLower(uniqueID))
	test_structure.SaveString(t, testFolder, "clusterName", clusterName)

	awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
}

func deployECSCluster(t *testing.T, testFolder string) {
	branchName := git.GetCurrentBranchName(t)
	awsRegion := test_structure.LoadString(t, testFolder, "region")
	clusterName := test_structure.LoadString(t, testFolder, "clusterName")
	awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

	terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["cluster_name"] = clusterName
	terraformOptions.Vars["cluster_min_size"] = 2
	terraformOptions.Vars["cluster_max_size"] = 2
	terraformOptions.Vars["cluster_instance_type"] = "t2.medium"
	terraformOptions.Vars["cluster_instance_ami_version_tag"] = branchName
	terraformOptions.Vars["cluster_instance_keypair_name"] = awsKeyPair.Name
	terraformOptions.Vars["enable_cloudwatch_log_aggregation"] = true
	terraformOptions.Vars["enable_ecs_cloudwatch_alarms"] = true
	terraformOptions.Vars["enable_ssh_grunt"] = false
	terraformOptions.Vars["enable_fail2ban"] = true
	terraformOptions.Vars["enable_ip_lockdown"] = false

	test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

func validateECSCluster(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	ecsClusterArn := terraform.OutputRequired(t, terraformOptions, "ecs_cluster_arn")
	clusterName := test_structure.LoadString(t, testFolder, "clusterName")
	awsRegion := test_structure.LoadString(t, testFolder, "region")

	assert.NotEmpty(t, ecsClusterArn)

	// Even after EC2 instances are successfully launched, it can take some time for them to be registered with the cluster
	logger.Logf(t, "Sleeping for %d minutes to wait for cluster instances", MinsToWaitForClusterInstances)
	time.Sleep(time.Minute * MinsToWaitForClusterInstances)

	// Sanity check that the cluster can be retrieved via the SDK and that it has at least 1 successfully registered container instance
	cluster := aws.GetEcsCluster(t, awsRegion, clusterName)
	assert.NotNil(t, cluster)

	instanceCount := int(*cluster.RegisteredContainerInstancesCount)
	require.Greater(t, instanceCount, 0)
}

// Verify that we can deploy an ecs service onto the ECS cluster that was previously created
func deployEcsService(t *testing.T, ecsClusterTestFolder string, ecsServiceTestFolder string) {

	awsRegion := test_structure.LoadString(t, ecsClusterTestFolder, "region")

	ecsClusterTerraformOptions := test_structure.LoadTerraformOptions(t, ecsClusterTestFolder)

	ecsServiceTerraformOptions := &terraform.Options{
		TerraformDir:             ecsServiceTestFolder,
		Vars:                     map[string]interface{}{},
		RetryableTerraformErrors: test.RetryableTerraformErrors,
		MaxRetries:               test.MaxTerraformRetries,
		TimeBetweenRetries:       test.SleepBetweenTerraformRetries,
	}

	ecsClusterArn := terraform.OutputRequired(t, ecsClusterTerraformOptions, "ecs_cluster_arn")
	clusterInstanceSecurityGroupId := terraform.OutputRequired(t, ecsClusterTerraformOptions, "ecs_instance_security_group_id")

	ecsClusterName := test_structure.LoadString(t, ecsClusterTestFolder, "clusterName")
	uniqueID := test_structure.LoadString(t, ecsClusterTestFolder, "uniqueID")
	domainName := fmt.Sprintf("ecs-service-test-%s.%s", uniqueID, TestDomainName)

	portMappings := map[string]int{
		"80": 80,
	}

	serviceName := fmt.Sprintf("nginx-%s", strings.ToLower(uniqueID))

	ecsServiceTerraformOptions.Vars["aws_region"] = awsRegion
	ecsServiceTerraformOptions.Vars["service_name"] = serviceName
	ecsServiceTerraformOptions.Vars["ecs_cluster_name"] = ecsClusterName
	ecsServiceTerraformOptions.Vars["ecs_cluster_arn"] = ecsClusterArn
	ecsServiceTerraformOptions.Vars["ecs_node_port_mappings"] = portMappings
	ecsServiceTerraformOptions.Vars["ecs_instance_security_group_id"] = clusterInstanceSecurityGroupId
	ecsServiceTerraformOptions.Vars["domain_name"] = domainName
	ecsServiceTerraformOptions.Vars["hosted_zone_id"] = TestHostedZoneId

	terraform.InitAndApply(t, ecsServiceTerraformOptions)

	test_structure.SaveTerraformOptions(t, ecsServiceTestFolder, ecsServiceTerraformOptions)
}

// Hit the load balancer via the route 53 record and ensure that nginx responds with the expected status code and response body
func validateECSService(t *testing.T, ecsClusterTestFolder, ecsServiceTestFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, ecsServiceTestFolder)
	applicationLoadBalancerFqdn := terraform.OutputRequired(t, terraformOptions, "route53_domain_name")

	expectedBody := "If you see this page, the nginx web server is successfully installed"
	body := bytes.NewReader([]byte(expectedBody))

	customValidation := func(statusCode int, response string) bool {
		return statusCode == 200 && strings.Contains(response, expectedBody)
	}

	http_helper.HTTPDoWithCustomValidation(t, "GET", fmt.Sprintf("https://%s", applicationLoadBalancerFqdn), body, nil, customValidation, nil)

}
