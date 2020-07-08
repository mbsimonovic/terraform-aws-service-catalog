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
	"github.com/stretchr/testify/assert"

	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestEcsCluster(t *testing.T) {
	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_build_ami", "true")
	// os.Setenv("SKIP_deploy_terraform", "true")
	// os.Setenv("SKIP_validate_cluster", "true")
	// os.Setenv("SKIP_deploy_ecs_service, "true")
	// os.Setenv("SKIP_cleanup", "true")
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

	defer test_structure.RunTestStage(t, "cleanup", func() {
		ecsClusterTerraformOptions := test_structure.LoadTerraformOptions(t, ecsClusterTestFolder)
		terraform.Destroy(t, terraformOptions)

		ecsServiceTerraformOptions := test_structure.LoadTerraformOptions(t, ecsServiceTestFolder)
		terraform.Destroy(t, ecsServiceTerraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		buildAmi(t, ecsClusterTestFolder)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployECSCluster(t, ecsClusterTestFolder)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateECSCluster(t, ecsClusterTestFolder)
	})

	test_structure.RunTestStage(t, "deploy_ecs_service", func() {
		deployEcsService(t, ecsClusterTestFolder, ecsServiceTestFolder)
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

	defaultVpc := aws.GetDefaultVpc(t, awsRegion)
	vpcSubnets := aws.GetSubnetsForVpc(t, defaultVpc.Id, awsRegion)
	var vpcSubnetIDs []string
	for _, sn := range vpcSubnets {
		vpcSubnetIDs = append(vpcSubnetIDs, sn.Id)
	}

	terraformOptions := createBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["cluster_name"] = clusterName
	terraformOptions.Vars["cluster_min_size"] = 1
	terraformOptions.Vars["cluster_max_size"] = 3
	terraformOptions.Vars["cluster_instance_type"] = "t2.medium"
	terraformOptions.Vars["cluster_instance_ami_version_tag"] = branchName
	terraformOptions.Vars["vpc_id"] = defaultVpc.Id
	terraformOptions.Vars["vpc_subnet_ids"] = vpcSubnetIDs
	terraformOptions.Vars["cluster_instance_keypair_name"] = awsKeyPair.Name
	terraformOptions.Vars["enable_cloudwatch_log_aggregation"] = true
	terraformOptions.Vars["enable_ecs_cloudwatch_alarms"] = true
	terraformOptions.Vars["enable_ssh_grunt"] = false
	terraformOptions.Vars["enable_fail2ban"] = true
	terraformOptions.Vars["enable_ip_lockdown"] = true

	test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

func validateECSCluster(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	ecsClusterArn := terraform.OutputRequired(t, terraformOptions, "ecs_cluster_arn")

	assert.NotEmpty(t, ecsClusterArn)
}

func deployEcsService(t *testing.T, ecsClusterTestFolder string, ecsServiceTestFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, ecsClusterTestFolder)
	clusterName := test_structure.LoadString(t, ecsClusterTestFolder, "clusterName")
	ecsClusterArn := terraform.OutputRequired(t, terraformOptions, "ecs_cluster_arn")
	uniqueID := test_structure.LoadString(t, ecsClusterTestFolder, "uniqueID")
	serviceName := fmt.Sprintf("nginx-%s", strings.ToLower(uniqueID))

	portMappings := map[string]int{
		"22":  22,
		"80":  80,
		"443": 443,
	}

	terraformOptions.Vars["service_name"] = serviceName
	terraformOptions.Vars["ecs_cluster_name"] = clusterName
	terraformOptions.Vars["ecs_cluster_arn"] = ecsClusterArn
	// TODO: cleanup the following vars
	terraformOptions.Vars["aws_region"] = "us-west-1"
	terraformOptions.Vars["image"] = "nginx"
	terraformOptions.Vars["image_version"] = "1.17"
	terraformOptions.Vars["vpc_env_var_name"] = "placeholder"
	terraformOptions.Vars["ecs_node_port_mappings"] = portMappings
	terraformOptions.Vars["alarm_sns_topic_arn"] = "TODO"
	terraformOptions.Vars["kms_master_key_arn"] = "TODO"
	terraformOptions.Vars["ecs_instance_security_group_id"] = "TODO"
	terraformOptions.Vars["db_primary_endpoint"] = "https://example.com"

	terraform.InitAndApply(t, terraformOptions)

}
